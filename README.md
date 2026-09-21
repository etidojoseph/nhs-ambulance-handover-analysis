# NHS Ambulance Handover Delay Analysis

A SQL and Python analysis of NHS England ambulance handover delays. It looks at which trusts fall furthest from the national handover standard, the operational and regional impact of those delays, seasonal patterns, and how well the mandated 45-minute maximum handover time is actually being met.

`Python` · `pandas` · `Microsoft SQL Server (T-SQL)` · `SSMS`

📄 **[Read the full write-up](docs/full_writeup.md)** for detailed methodology, all data quality fixes, and the complete findings.

---

## Why this project

I work in a private care home, and I see first-hand how much patient outcomes depend on the wider urgent care system moving quickly. Ambulance handover delays kept coming up in the news, and I wanted to move past the headline and find out specifically which trusts were struggling most against the NHS's own 15-minute standard. That kind of trust-level answer is what could actually help target support, instead of just confirming the system is under pressure in general.

## The Four Questions

| # | Question | Why it matters |
|---|---|---|
| 1 | Which trusts are furthest from the NHS handover standard? | National averages show that the system is under pressure, but not where to target support |
| 2 | What is the real-world impact, in lost ambulance crew hours? | Turns a ranking into a figure that actually means something operationally |
| 3 | Is delay seasonal? Does it spike over winter? | Tests the "winter pressures" narrative against real data |
| 4 | Is the mandated 45-minute standard being met? | The standard was mandated in August 2025, so this checks compliance and trend since then |

## Key Findings

- **RGM (Royal Papworth)** has the worst handover rate (84% of handovers breach the 30-minute standard). **RRK (Birmingham)** has the biggest raw impact (18,410 patients delayed). Different trusts top different measures, so both are reported, filtered to trusts with at least 100 handovers to avoid low-volume statistical noise.
- **RRK alone lost an estimated 35,559 ambulance crew-hours** to delay over the 126-day period studied. That works out to roughly 282 hours a day.
- **Midlands and East of England lose 9 to 11 times more crew-hours per handover** than the South East, even after normalizing for trust size.
- The common assumption is that Christmas is the worst period. It isn't. The actual peak was **4 to 18 January 2026**, with the single worst day being 9 January, confirmed independently across three separate metrics (breach rate, lost hours, average duration).
- **RM1 (Norfolk and Norwich)** still breaches the mandated 45-minute ceiling on 40.3% of handovers, months after the national mandate took effect in August 2025. National compliance improved modestly over the winter, from 12.8% to 11.7%. This is reported as a compliance trend, not a causal policy effect, since there's no pre-policy baseline in this dataset to compare against.

## Skills Demonstrated

- **Data engineering (Python/pandas):** parsed a roughly 1,780-column wide-format Excel export, where each date was spread across its own repeating column block, and reshaped it into a normalized relational structure of two linked tables instead of one wide sheet
- **Data modeling:** designed a `trusts`/`handovers` schema with a composite primary key (`trust_code`, `date`) and an enforced foreign key relationship
- **SQL data cleaning:** converted placeholder text (`'-'`) to proper `NULL`s, resolved a mixed-type column bug, and standardized inconsistent numeric precision
- **Advanced string parsing (T-SQL):** used `CROSS APPLY` with `CHARINDEX`/`SUBSTRING` to parse inconsistent time-duration text (`H:MM:SS[.ffffff]`) into a clean numeric field, since no built-in function handled that format directly
- **Window functions:** `RANK() OVER`, and 7-day rolling averages via `AVG() OVER (... ROWS BETWEEN 6 PRECEDING AND CURRENT ROW)` to smooth daily noise and surface a seasonal trend
- **CTEs** for multi-step aggregation logic
- **Data validation:** primary and foreign key constraints, plus explicit duplicate checks, used as actual proof of data integrity rather than assumed
- **Statistical judgement:** identified and corrected a small-sample-size ranking distortion, and tested (then ruled out) whether a simpler aggregation method introduced bias before adopting it
- **Idempotent SQL:** wrapped schema-altering statements in `IF NOT EXISTS` checks so setup scripts can be safely run more than once

## Methodology

Python and pandas reshape the raw wide-format NHS export into two normalized tables (`trusts` and `handovers`). SQL Server handles the rest: loading, cleaning (placeholder-to-`NULL` conversion, type casting, custom time-string parsing with `CROSS APPLY`/`CHARINDEX`), integrity validation (primary/foreign keys, duplicate checks), and all of the analysis itself (window functions, CTEs, ranked aggregates).

For the full details, including all 6 data quality issues found and fixed, sensitivity checks on ranking thresholds (tested at 100, 500, and 1,000 handovers), and three analytical approaches that were tested and rejected for Q4 before landing on a defensible one, see the [full write-up](docs/full_writeup.md).

## Limitations

- The volume threshold (100 or more handovers) used in rankings is a judgement call. It was sensitivity-tested at 100/500/1,000 but isn't a fixed rule.
- Q4 measures policy compliance, not causation. The dataset has no pre-policy baseline, since the policy was mandated in August 2025, before this data even begins.
- Regional findings don't control for hospital case mix.

For the full limitations and next steps, see the [full write-up](docs/full_writeup.md).

## Repo Structure

```
├── README.md
├── docs/
│   └── full_writeup.md          <- full methodology, data quality log, detailed findings
├── scripts/
│   ├── 01_create_tables.sql     <- schema + integrity constraints
│   ├── 02_data_cleaning.sql     <- NULL handling, type conversion, time parsing
│   ├── 03_q1_headline_ranking.sql
│   ├── 04_q2_lost_hours.sql
│   ├── 05_q3_winter_trend.sql
│   └── 06_q4_policy_compliance.sql
├── data/
│   ├── raw/
│   │   └── Web-File-Timeseries-Ambulance-Collection-dpkj63.xlsx
│   └── processed/
│       ├── trusts.csv
│       └── handovers.csv
└── reshape_handovers.py         <- wide-to-long reshape script
```

## Data Source

NHS England's Urgent and Emergency Care Daily Situation Reports (UEC Sitrep), covering 24 November 2025 to 29 March 2026, downloaded as a combined time-series export. [View the source page](https://www.england.nhs.uk/statistics/statistical-work-areas/uec-sitrep/urgent-and-emergency-care-daily-situation-reports-2025-26/).
