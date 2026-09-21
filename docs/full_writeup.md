# Full Project Write-Up: NHS Ambulance Handover Delay Analysis

This document contains the full methodology, data quality findings, detailed results, and limitations for the project. See the main [README](../README.md) for the quick-scan summary.

## Motivation

I work in a private care home, and I see first-hand how much patient outcomes depend on the wider urgent care system moving quickly. Ambulance handover delays kept coming up in the news, and I wanted to move past the headline and find out specifically which trusts were struggling most against the NHS's own 15-minute standard. That kind of trust-level answer is what could actually help target support, instead of just confirming the system is under pressure in general.

NHS research backs up why this matters. AACE found that over 80% of patients waiting 60 or more minutes for handover experienced some level of harm, and HSSIB's national investigation frames handover delay as a whole-system flow problem rather than an ambulance service failure specifically.

## Data Source

- **Source**: NHS England's Urgent and Emergency Care Daily Situation Reports (UEC Sitrep)
- **Source page**: https://www.england.nhs.uk/statistics/statistical-work-areas/uec-sitrep/urgent-and-emergency-care-daily-situation-reports-2025-26/
- **File**: `Web-File-Timeseries-Ambulance-Collection-dpkj63.xlsx`, a combined time-series export
- **Period covered**: 24 November 2025 to 29 March 2026 (126 days)
- **Granularity**: daily, per NHS Trust
- **Note**: NHS England also publishes single-month files for later periods, such as April 2026 onward, but at a different and coarser grain (one row per trust per month, not per day) with a different schema. These were evaluated but excluded from this analysis to avoid mixing incompatible grains. See Limitations and Next Steps below.

## Methodology

1. **Extract and reshape (Python/pandas).** The raw file stores each date as its own repeating 14-column block, roughly 1,780 columns in total. `reshape_handovers.py` unpivots this into a long format and splits it into two normalized tables: `trusts` (one row per trust) and `handovers` (one row per trust per day), linked by `trust_code`.
2. **Load (SQL Server / SSMS).** Both tables were imported through the Import Flat File wizard, with column types and nullability set deliberately (see Data Cleaning below).
3. **Validate.** Added a composite primary key (`trust_code`, `date`) and a foreign key back to `trusts`. Both succeeded on the first attempt, and an explicit `GROUP BY ... HAVING COUNT(*) > 1` duplicate check confirmed zero duplicates in either table.
4. **Clean (SQL).** See below.
5. **Analyse (SQL).** Window functions (`RANK()`, rolling `AVG() OVER`), CTEs, and aggregate queries were used to answer the four questions.

## Data Quality Issues Found During Validation

| # | Issue | Resolution |
|---|---|---|
| 1 | `total_hours` had inconsistent decimal precision | Standardised with `ROUND()` in SQL |
| 2 | `pct_over_*` columns imported as text instead of numeric | Raw `'-'` values, which is NHS's marker for "not calculable," were converted to `NULL` in SQL, then the columns were cast to `FLOAT` |
| 3 | 4 trusts (RT1, RYV, RWR, RY3) showed mostly blank or zero data | Initially assumed to be zero-activity trusts. Later confirmed via SQL that all 4 have some genuine activity, between 3 and 49 total handovers over the period, just too low-volume to rank fairly. Addressed with a minimum volume threshold (100 or more total handovers) in ranking queries rather than exclusion |
| 4 | A footer "Contact:" row was misread as a fake 149th trust during reshaping | Root cause: the Python filter only checked for `NULL`, not a valid trust code format. Fixed by validating that a real NHS trust code is always exactly 3 characters |
| 5 | The same fake trust/contact row leaked into both output tables | Same fix as #4, resolved at the source in the reshape script |
| 6 | `mean_time` stored as inconsistent text, for example `0:19:21.187000` versus `00:27:15` | Parsed in SQL using `CHARINDEX` and `SUBSTRING` string functions into a new numeric `mean_seconds` column |

## Detailed Findings

### Q1: Which trusts are furthest from the NHS handover standard?

Two complementary rankings were built:

**Rate-based**, which shows whose process is worst proportionally. Topped by RGM (Royal Papworth Hospital) at an 84% breach rate on the 30-minute standard.

**Impact-based**, which shows where the most actual patients are affected in raw numbers. Topped by RRK (University Hospitals Birmingham) at 18,410 delayed patients over the period.

A minimum volume threshold of 100 or more total handovers was applied after a small-sample distortion was found. RT1, with only 49 total handovers across 126 days, initially ranked near the top purely from statistical noise in its percentage. The threshold was sensitivity-tested at 100, 500, and 1,000 handovers, and results stayed reasonably stable across thresholds once genuinely low-volume trusts were excluded.

An additional check confirmed that averaging daily percentages (`AVG(pct_over_30)`) versus pooling raw counts first (`SUM(over_30)/SUM(handover_known)`) produced near-identical rankings, differing by at most one position, so the simpler method was kept with confidence.

### Q2: Lost ambulance hours

"Lost hours" was calculated as time spent beyond the 15-minute standard (`total_hours - handover_known × 0.25`), not total handover time. This matches the methodology used in published NHS and AACE analyses.

RRK (Birmingham) alone lost an estimated 35,559 crew-hours to handover delay over the 126-day period, roughly 282 crew-hours per day, which is equivalent to a dozen ambulance crews sat idle outside A&E around the clock.

A regional breakdown, normalised for trust size (lost hours per handover, not raw totals), found the Midlands (0.577 lost hours per handover) and East of England (0.465) far exceed the South East (0.051). That's an 11x difference that holds even after controlling for volume, ruling out "bigger region means worse region" as the explanation.

### Q3: Seasonal trend

A national daily rate was calculated by pooling all trusts (`SUM(over_30)/SUM(handover_known)` per day), then smoothed with a 7-day rolling average window function to remove weekday and weekend noise.

The common assumption is that Christmas is the worst period. It isn't. The 15 worst days by rolling average all fell between 4 and 18 January 2026, peaking on 9 January. A monthly comparison, corrected for partial months at the start and end of the dataset, confirmed January was the worst month on all three measures tested: breach rate (32.5%), lost hours per day (5,030), and average handover duration (36.3 minutes). March was consistently the best month on all three.

A secondary finding: November had a similar 30-minute breach rate to December, but a notably higher lost-hours-per-day figure. Investigation ruled out volume differences, which were flat across all months, and instead found that November actually had a longer average handover duration than December. This shows that a single threshold-based metric like `pct_over_30` can miss real patterns that are visible in the raw duration data.

### Q4: 45-minute standard compliance

The national mandate for the 45-minute maximum handover standard, part of NHS England's "Release to Rescue" or W45 policy, took effect in August 2025, before this dataset begins on 24 November 2025. This meant a causal before/after test wasn't possible. The entire dataset falls after the mandate, so there's no "before" period to compare against.

Three alternative frameworks were considered and rejected: a guessed calendar-date split, a ratio-based "natural scaling" argument, and a day-by-day retention-rate narrative. Each shared the same underlying flaw, which is that none of them had a pre-policy baseline to attribute any observed pattern specifically to the policy.

The question was reframed from causation to compliance: which trusts are still breaching the mandated ceiling months after it was supposed to be in force without exception, and is compliance improving toward NHS England's own stated year-end goal?

The worst trust was RM1 (Norfolk and Norwich) at 40.3% non-compliance. The same two regions flagged in Q2, Midlands and East of England, dominate this ranking too, which is a cross-metric pattern across two independently built queries. National compliance improved modestly across the winter, from 12.8% pre-peak to 11.7% post-peak, using the exact 4 to 18 January peak window identified empirically in Q3. This is directionally consistent with NHS England's stated goal of improvement by year-end.

A monthly-resolution breakdown of the two mandated thresholds confirms this holds at finer granularity and extends to the most severe delay tier. `pct_over_45` moved from 14.1% (November) to 11.2% (December) to 16.3% (January, the peak) to 12.3% (February) to 8.5% (March), and `pct_over_60` followed an identical shape: 9.1%, 7.3%, 11.5%, 8.2%, 5.2%. The problem isn't concentrated in one severity band. The whole delay distribution shifts together across the season. As with the 3-period comparison above, this describes a seasonal pattern. It can't be used to determine whether the policy itself succeeded, failed, or is unrelated to the trend, since no pre-policy baseline exists in this dataset.

## Limitations

- **Volume threshold:** the minimum of 100 total handovers used in rankings is a judgement call. It was sensitivity-tested at 500 and 1,000 handovers and found reasonably stable, but the exact cutoff isn't a fixed rule and could be revisited.
- **Q4 measures compliance, not causation:** because the entire dataset falls after the policy's national mandate, no pre-policy baseline exists. Improvement over the winter is consistent with the policy's stated goals but can't be causally attributed to it.
- **Case mix isn't controlled for:** regional findings may partly reflect hospital type (general versus specialist) or patient acuity mix rather than purely operational performance.
- **Data grain mismatch limits extension:** later monthly NHS files from April 2026 onward use a different structure, monthly total per trust rather than daily, and weren't merged into this analysis for that reason. See Next Steps.

## Next Steps

- Extend the analysis with April to August 2026 monthly data, clearly labelled as a lower-resolution supplementary view rather than merged into the daily dataset
- Add a visual dashboard summarising the key findings for a non-technical audience
- Investigate case-mix data to test whether the regional disparity in Q2 and Q4 holds after adjusting for hospital type
