-- ============================================================
-- 02_data_cleaning.sql
-- Cleans the raw imported data: converts NHS's '-' ("not
-- calculable") placeholder to proper NULLs, converts cleaned
-- columns to numeric types, and parses mean_time (inconsistent
-- text) into a usable numeric column.
-- ============================================================

-- --- Step 1: convert '-' placeholders to real NULLs ---------
-- '-' appears when a trust had zero known-time handovers on a
-- given day, making the percentage genuinely undefined (not
-- zero). Found in 29 distinct trusts across the dataset, not
-- just the 4 lowest-volume ones initially suspected.

-- mean_time must allow NULLs before this UPDATE can run.
-- (ALTER COLUMN is naturally safe to re-run -- unlike ADD, it
-- doesn't error if the column already has this definition -- so
-- no IF NOT EXISTS guard is needed here or on the FLOAT
-- conversions in Step 2 below.)
ALTER TABLE handovers ALTER COLUMN mean_time NVARCHAR(50) NULL;

UPDATE handovers SET pct_over_15  = NULL WHERE pct_over_15  = '-';
UPDATE handovers SET pct_over_30  = NULL WHERE pct_over_30  = '-';
UPDATE handovers SET pct_over_45  = NULL WHERE pct_over_45  = '-';
UPDATE handovers SET pct_over_60  = NULL WHERE pct_over_60  = '-';
UPDATE handovers SET pct_unknown  = NULL WHERE pct_unknown  = '-';
UPDATE handovers SET mean_time    = NULL WHERE mean_time    = '-';

-- --- Step 2: convert the now-clean pct_ columns to FLOAT -----
-- Only possible now that '-' values are gone -- SQL Server
-- rejects a conversion to FLOAT if any non-numeric text remains,
-- so this step depends on Step 1 running first.
ALTER TABLE handovers ALTER COLUMN pct_over_15 FLOAT NULL;
ALTER TABLE handovers ALTER COLUMN pct_over_30 FLOAT NULL;
ALTER TABLE handovers ALTER COLUMN pct_over_45 FLOAT NULL;
ALTER TABLE handovers ALTER COLUMN pct_over_60 FLOAT NULL;
ALTER TABLE handovers ALTER COLUMN pct_unknown FLOAT NULL;

-- --- Step 3: parse mean_time into a numeric column -----------
-- mean_time is stored as text in the format H:MM:SS or
-- H:MM:SS.ffffff (e.g. '0:19:21.187000' or '00:27:15') --
-- inconsistent because it came from Excel's mixed
-- timedelta/time formatting. Split on the colons to extract
-- hours/minutes/seconds separately, then combine into one
-- number (total seconds) that can be used in AVG(), comparisons,
-- etc.
--
-- Guarded with IF NOT EXISTS, unlike the ALTER COLUMN statements
-- above: re-running ALTER COLUMN on an existing column is safe,
-- but ADD fails with "column already exists" on a second run --
-- this check makes the script safely re-runnable either way.
IF NOT EXISTS (
    SELECT * FROM sys.columns
    WHERE object_id = OBJECT_ID('handovers') AND name = 'mean_seconds'
)
BEGIN
    ALTER TABLE handovers ADD mean_seconds FLOAT NULL;
END;

UPDATE h
SET h.mean_seconds =
    CAST(LEFT(h.mean_time, p.c1 - 1) AS FLOAT) * 3600
    + CAST(SUBSTRING(h.mean_time, p.c1 + 1, p.c2 - p.c1 - 1) AS FLOAT) * 60
    + CAST(SUBSTRING(h.mean_time, p.c2 + 1, LEN(h.mean_time) - p.c2) AS FLOAT)
FROM handovers h
CROSS APPLY (
    SELECT
        c1 = CHARINDEX(':', h.mean_time),
        c2 = CHARINDEX(':', h.mean_time, CHARINDEX(':', h.mean_time) + 1)
) p
WHERE h.mean_time IS NOT NULL;

-- --- Verification -------------------------------------------
-- Spot check: values should be sensible handover durations
-- (tens of minutes = hundreds/low thousands of seconds), not
-- negative, huge, or unexpectedly NULL.
SELECT TOP 10 trust_code, handover_date, mean_time, mean_seconds
FROM handovers
WHERE mean_time IS NOT NULL;

-- Confirm all pct_ columns are now FLOAT, not text
SELECT COLUMN_NAME, DATA_TYPE
FROM nhs_ambulance_project.INFORMATION_SCHEMA.COLUMNS
WHERE TABLE_NAME = 'handovers' AND COLUMN_NAME LIKE 'pct_%';
