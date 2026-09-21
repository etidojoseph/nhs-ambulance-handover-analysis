-- ============================================================
-- 05_q3_winter_trend.sql
-- Q3: Is delay seasonal -- does it spike over winter?
-- ============================================================

-- --- National daily rate + 7-day rolling average -----------------
-- Pools every trust into one national daily figure first
-- (SUM/SUM, not an average of trust percentages), then applies a
-- 7-day rolling average via a window function to smooth out
-- weekday/weekend noise and reveal the underlying trend.
;WITH daily_national AS (
    SELECT
        handover_date,
        SUM(over_30) * 1.0 / NULLIF(SUM(handover_known), 0) AS pct_over_30,
        SUM(all_handovers) AS total_handovers,
        SUM(total_hours - (handover_known * 0.25)) AS lost_hours
    FROM handovers
    GROUP BY handover_date
),
rolling AS (
    SELECT
        handover_date,
        pct_over_30,
        lost_hours,
        AVG(pct_over_30) OVER (ORDER BY handover_date ROWS BETWEEN 6 PRECEDING AND CURRENT ROW) AS roll_pct,
        AVG(lost_hours) OVER (ORDER BY handover_date ROWS BETWEEN 6 PRECEDING AND CURRENT ROW) AS roll_lost
    FROM daily_national
)
-- Worst 15 days by rolling average -- identifies the ACTUAL peak,
-- rather than assuming it's Christmas. Result: all 15 fell in
-- 4-18 Jan 2026, peaking 9 Jan -- not the holiday period itself.
SELECT TOP 15
    handover_date,
    ROUND(roll_pct, 3) AS rolling_7day_pct_over_30,
    ROUND(roll_lost, 0) AS rolling_7day_lost_hours
FROM rolling
ORDER BY roll_pct DESC;

-- --- Monthly comparison, corrected for partial months ------------
-- Nov (7 days) and Mar (29 days) are partial months -- comparing
-- raw totals against full months (Dec/Jan: 31 days) would
-- understate them. Dividing by actual day count gives a fair
-- "typical day" comparison across all 5 months.
SELECT
    YEAR(handover_date) AS yr,
    MONTH(handover_date) AS mth,
    COUNT(DISTINCT handover_date) AS days_in_period,
    ROUND(SUM(over_30) * 1.0 / NULLIF(SUM(handover_known), 0), 3) AS pct_over_30,
    ROUND(SUM(total_hours - (handover_known * 0.25)) / COUNT(DISTINCT handover_date), 0) AS avg_lost_hours_per_day
FROM handovers
GROUP BY YEAR(handover_date), MONTH(handover_date)
ORDER BY yr, mth;

-- --- Anomaly check: why was November's lost_hours high despite --
-- --- a similar breach rate to December? --------------------------
-- Ruled out volume (flat across months, ~13,700-14,150/day).
-- Confirmed instead by average handover duration: November had
-- longer average handovers (32.5 min) than December (29.3 min),
-- showing pct_over_30 alone misses handovers in the "over
-- standard but under 30 min" zone.
SELECT
    YEAR(handover_date) AS yr,
    MONTH(handover_date) AS mth,
    ROUND(AVG(mean_seconds) / 60.0, 1) AS avg_mean_minutes
FROM handovers
WHERE mean_seconds IS NOT NULL
GROUP BY YEAR(handover_date), MONTH(handover_date)
ORDER BY yr, mth;
