# NHS Ambulance Handover Delay Analysis

**A SQL and Python analysis of NHS England ambulance handover delays**, identifying which trusts fall furthest from national standards, the operational and regional impact of those delays, seasonal patterns, and compliance with the mandated 45-minute maximum handover time.

`Python` · `pandas` · `Microsoft SQL Server (T-SQL)` · `SSMS`

📄 **[Read the full write-up](docs/full_writeup.md)** — detailed methodology, all data quality fixes, and complete findings.

---

## Why this project

I work in a private care home and see first-hand how much patient outcomes depend on the wider urgent care system moving quickly. Ambulance handover delays kept coming up in the news, and I wanted to move past the headline and find out specifically *which* trusts were struggling most against the NHS's own 15-minute standard — the kind of trust-level answer that could actually help target support, rather than just confirming the system is under pressure in general.

## The Four Questions

| # | Question | Why it matters |
|---|---|---|
| 1 | Which trusts are furthest from the NHS handover standard? | National averages show pressure but not *where* to target support |
| 2 | What is the real-world impact, in lost ambulance crew hours? | Turns a ranking into an operational, resourcing-relevant figure |
| 3 | Is delay seasonal — does it spike over winter? | Tests the "winter pressures" narrative against real data |
| 4 | Is the mandated 45-minute standard being met? | The standard was mandated in Aug 2025 — this checks compliance and trend |

## Key Findings

- **RGM (Royal Papworth)** has the worst handover *rate* (84% breach the 30-min standard); **RRK (Birmingham)** has the biggest raw *impact* (18,410 patients delayed) — different trusts top different measures, so both are reported, filtered to trusts with ≥100 handovers to avoid low-volume statistical noise.
- **RRK alone lost an estimated 35,559 ambulance crew-hours** to delay over the 126-day period — roughly 282 hours/day.
- **Midlands and East of England lose 9–11x more crew-hours per handover** than the South East, even after normalizing for trust size.
- Contrary to the "Christmas is worst" assumption, the actual peak was **4–18 January 2026** (worst day: 9 Jan) — confirmed independently across three metrics (breach rate, lost hours, average duration).
- **RM1 (Norfolk and Norwich)** still breaches the mandated 45-min ceiling on 40.3% of handovers, months after the national mandate took effect (Aug 2025). National compliance improved modestly over the winter (12.8% → 11.7%) — reported as a compliance trend, not a causal policy effect, since no pre-policy baseline exists in this dataset.

## Skills Demonstrated

- **Data engineering (Python/pandas):** parsed a ~1,780-column wide-format Excel export (each date spread across its own repeating column block) and reshaped it into a normalized relational structure — two linked tables instead of one wide sheet
- **Data modeling:** designed a `trusts`/`handovers` schema with a composite primary key (`trust_code`, `date`) and enforced foreign key relationship
- **SQL data cleaning:** converted placeholder text (`'-'`) to proper `NULL`s, resolved a mixed-type column bug, standardized inconsistent numeric precision
- **Advanced string parsing (T-SQL):** used `CROSS APPLY` and `CHARINDEX`/`SUBSTRING` to parse inconsistent time-duration text (`H:MM:SS[.ffffff]`) into a clean numeric field, with no built-in function available for the job
- **Window functions:** `RANK() OVER`, and 7-day rolling averages via `AVG() OVER (... ROWS BETWEEN 6 PRECEDING AND CURRENT ROW)` to smooth daily noise and surface a seasonal trend
- **CTEs** for multi-step aggregation logic
- **Data validation:** primary/foreign key constraints and explicit duplicate checks used as proof of data integrity, not just assumed
- **Statistical judgement:** identified and corrected a small-sample-size ranking distortion; tested (and ruled out) whether a simpler aggregation method introduced bias before adopting it
- **Idempotent SQL:** wrapped schema-altering statements in `IF NOT EXISTS` checks so setup scripts can be safely re-run

## Methodology

**Python (pandas)** reshapes the raw wide-format NHS export into two normalized tables (`trusts`, `handovers`). **SQL Server** handles loading, cleaning (placeholder-to-`NULL` conversion, type casting, custom time-string parsing via `CROSS APPLY`/`CHARINDEX`), integrity validation (primary/foreign keys, duplicate checks), and all analysis (window functions, CTEs, ranked aggregates).

Full details — all 6 data quality issues found and fixed, sensitivity checks on ranking thresholds (tested at 100/500/1,000 handovers), and three analytical approaches tested and rejected for Q4 before landing on a defensible one → **[see full write-up](docs/full_writeup.md)**.

## Limitations

- Volume threshold (≥100 handovers) used in rankings is a judgement call, sensitivity-tested at 100/500/1,000 but not a fixed rule
- Q4 measures policy *compliance*, not causation — the dataset has no pre-policy baseline (the policy was mandated Aug 2025, before this data begins)
- Regional findings don't control for hospital case mix

Full limitations and next steps → [see full write-up](docs/full_writeup.md).

## Repo Structure

```
├── README.md
├── docs/
│   └── full_writeup.md          ← full methodology, data quality log, detailed findings
├── scripts/
│   ├── 01_create_tables.sql     ← schema + integrity constraints
│   ├── 02_data_cleaning.sql     ← NULL handling, type conversion, time parsing
│   ├── 03_q1_headline_ranking.sql
│   ├── 04_q2_lost_hours.sql
│   ├── 05_q3_winter_trend.sql
│   └── 06_q4_policy_compliance.sql
├── data/processed/
│   ├── trusts.csv
│   └── handovers.csv
└── reshape_handovers.py         ← wide-to-long reshape script
```

## Data Source

NHS England Daily Ambulance Collection, 24 Nov 2025 – 29 Mar 2026. [NHS England Ambulance Quality Indicators](https://www.england.nhs.uk/statistics/statistical-work-areas/ambulance-quality-indicators/ambulance-management-information/)
