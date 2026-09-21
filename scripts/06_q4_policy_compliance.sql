-- ============================================================
-- 06_q4_policy_compliance.sql
-- Q4: Is the mandated 45-minute maximum handover standard being met?
--
-- IMPORTANT CONTEXT: NHS England's "Release to Rescue"/W45 policy
-- was mandated nationally in August 2025 -- before this dataset
-- begins (24 Nov 2025). This means a causal before/after test is
-- NOT possible: there is no "before" period in the data. Three
-- alternative frameworks (a guessed calendar-date split, a
-- ratio-based "natural scaling" argument, and a day-by-day
-- retention-rate narrative) were each considered and rejected --
-- all shared the same flaw of implying causation without a
-- pre-policy baseline to compare against.
--
-- Reframed instead as a COMPLIANCE question: who is still
-- breaching the mandated standard, and is compliance trending
-- toward NHS England's own stated "improvement by year-end" goal?
-- ============================================================

-- --- Non-compliance ranking ---------------------------------------
-- Reuses the exact method + volume floor validated in Q1
-- (AVG(pct_over_45), >=100 handovers) rather than recalculating
-- from raw counts -- Q1 already confirmed the two approaches give
-- near-identical results.
SELECT
    RANK() OVER (ORDER BY AVG(h.pct_over_45) DESC) AS non_compliance_rank,
    t.trust_code, t.trust_name, t.region,
    ROUND(AVG(h.pct_over_45), 3) AS avg_pct_over_45,
    SUM(h.over_45) AS total_breaches_over_45,
    SUM(h.all_handovers) AS total_handovers
FROM handovers h
JOIN trusts t ON h.trust_code = t.trust_code
GROUP BY t.trust_code, t.trust_name, t.region
HAVING SUM(h.all_handovers) >= 100
ORDER BY non_compliance_rank;

-- --- Trend across the winter (3-period) ---------------------------
-- Period boundaries (4 Jan, 18 Jan) are NOT arbitrary -- they come
-- directly from Q3's own empirical finding: the 15 worst days by
-- rolling average all fell in this exact window, peaking 9 Jan.
-- Descriptive trend only, not a policy-effect test (see note above).
SELECT
    CASE
        WHEN handover_date < '2026-01-04' THEN '1_pre_peak'
        WHEN handover_date <= '2026-01-18' THEN '2_peak_period'
        ELSE '3_post_peak'
    END AS period,
    ROUND(SUM(over_45) * 1.0 / NULLIF(SUM(handover_known), 0), 3) AS pct_over_45,
    ROUND(SUM(total_hours - (handover_known * 0.25)) / COUNT(DISTINCT handover_date), 0) AS avg_lost_hours_per_day
FROM handovers
GROUP BY CASE
        WHEN handover_date < '2026-01-04' THEN '1_pre_peak'
        WHEN handover_date <= '2026-01-18' THEN '2_peak_period'
        ELSE '3_post_peak'
    END
ORDER BY period;

-- --- Supplementary: monthly-resolution view of both mandated -----
-- --- thresholds (45 min and 60 min) -------------------------------
-- Confirms the 3-period trend holds at finer granularity, and
-- extends to the most severe delay tier (>60 min), which moves in
-- lockstep with >45 min -- the whole delay distribution shifts
-- together across the season, not just one severity band.
SELECT
    DATEPART(year, h.handover_date) AS handover_year,
    DATEPART(month, h.handover_date) AS handover_month,
    COUNT(DISTINCT h.handover_date) AS active_days,
    ROUND(AVG(h.pct_over_45), 3) AS avg_pct_over_45,
    ROUND(AVG(h.pct_over_60), 3) AS avg_pct_over_60,
    ROUND(AVG(h.mean_seconds) / 60.0, 2) AS avg_mean_minutes,
    ROUND(SUM(h.total_hours - (h.handover_known * 0.25)) / COUNT(DISTINCT h.handover_date), 0) AS excess_lost_hours_per_day
FROM handovers h
GROUP BY DATEPART(year, h.handover_date), DATEPART(month, h.handover_date)
ORDER BY handover_year ASC, handover_month ASC;
