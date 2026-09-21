"""
Reshape the NHS ambulance handover file from "wide" (one row per trust,
~40 metrics repeated for every date across the columns) into two tidy
tables ready to load into SQL:

    trusts.csv     -> one row per NHS Trust        (trust_code, trust_name, region)
    handovers.csv  -> one row per trust PER DAY     (trust_code, date, over_15, ...)

Run with:  python3 reshape_handovers.py
"""

import os
import openpyxl
import pandas as pd
from datetime import datetime

# ---------------------------------------------------------------------
# STEP 0: settings for this specific file
# ---------------------------------------------------------------------
FILE_PATH = "data/raw/Web-File-Timeseries-Ambulance-Collection-dpkj63.xlsx"
SHEET_NAME = "Handovers"

DATE_ROW_INDEX = 2      # row (0-indexed) that holds the date for each block of columns
FIRST_DATA_ROW = 9      # row where individual trust data starts
FIRST_DATE_COL = 3      # columns 0,1,2 are Region / Trust code / Trust name

# The 14 fields that repeat, in order, for every single date
FIELD_NAMES = [
    "handover_known", "over_15", "over_30", "over_45", "over_60",
    "handover_unknown", "all_handovers", "total_hours", "mean_time",
    "pct_over_15", "pct_over_30", "pct_over_45", "pct_over_60", "pct_unknown",
]
BLOCK_SIZE = len(FIELD_NAMES)  # 14 columns make up one date's worth of data

# ---------------------------------------------------------------------
# STEP 1: load the raw sheet as a plain list of rows
# ---------------------------------------------------------------------
wb = openpyxl.load_workbook(FILE_PATH, data_only=True)
ws = wb[SHEET_NAME]
rows = list(ws.iter_rows(values_only=True))

date_row = rows[DATE_ROW_INDEX]
data_rows = rows[FIRST_DATA_ROW:]

# ---------------------------------------------------------------------
# STEP 2: work out which date each column belongs to.
# The date only appears once at the START of each 14-column block
# (a "merged cell" effect) -- every other column in that block is
# blank in this row, so we carry the last-seen date forward.
# ---------------------------------------------------------------------
col_to_date = {}
current_date = None
for col_idx, value in enumerate(date_row):
    if isinstance(value, datetime):
        current_date = value.date()
    if col_idx >= FIRST_DATE_COL:
        col_to_date[col_idx] = current_date

# ---------------------------------------------------------------------
# STEP 3: walk every trust row, and every 14-column block within it,
# building the two tidy tables as we go.
# ---------------------------------------------------------------------
def is_valid_trust_code(value):
    """Real NHS trust codes are always exactly 3 characters (e.g. RC9, RGT).
    This filters out footer rows like ('Contact:', 'england.999iucdata@nhs.net', ...)
    which have a non-None value in the trust_code column but aren't a real trust."""
    return isinstance(value, str) and len(value) == 3


trusts = {}          # trust_code -> (trust_name, region)   -- de-duplicated automatically by dict
handover_records = []  # one dict per trust-per-day row

for row in data_rows:
    trust_code = row[1]
    if not is_valid_trust_code(trust_code):
        # skips blank rows, the "Unknown" site row, and the footer/contact notes
        continue

    region, trust_name = row[0], row[2]
    trusts[trust_code] = (trust_name, region)

    # step through the row in chunks of 14 columns, one chunk per date
    for col_idx in range(FIRST_DATE_COL, len(row), BLOCK_SIZE):
        date = col_to_date.get(col_idx)
        if date is None:
            continue
        values = row[col_idx: col_idx + BLOCK_SIZE]
        record = {"trust_code": trust_code, "date": date}
        record.update(dict(zip(FIELD_NAMES, values)))
        # NOTE: values are passed through raw here -- '-' strings,
        # inconsistent decimal precision, and mixed timedelta/time
        # objects in mean_time are left as-is deliberately. Cleaning
        # these is done in SQL after loading, not here. This script's
        # only job is correctly reshaping wide -> long.
        handover_records.append(record)

# ---------------------------------------------------------------------
# STEP 4: turn the collected data into DataFrames and save as CSV
# ---------------------------------------------------------------------
trusts_df = pd.DataFrame(
    [(code, name, region) for code, (name, region) in trusts.items()],
    columns=["trust_code", "trust_name", "region"],
)

handovers_df = pd.DataFrame(handover_records)

os.makedirs("data/processed", exist_ok=True)
trusts_df.to_csv("data/processed/trusts.csv", index=False)
handovers_df.to_csv("data/processed/handovers.csv", index=False)

print(f"trusts.csv: {len(trusts_df)} rows")
print(f"handovers.csv: {len(handovers_df)} rows")
print(trusts_df.head())
print(handovers_df.head())
