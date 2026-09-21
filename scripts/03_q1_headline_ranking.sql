-- ============================================================
-- 03_q1_headline_ranking.sql
-- Q1: Which trusts are furthest from the NHS handover standard?
--
-- Two complementary rankings:
--   A) Rate-based   -- whose PROCESS is worst, proportionally
--   B) Impact-based -- where the most PATIENTS are affected, in
--                      raw numbers
--
-- Both use a >=100 total-handovers volume floor. This was added
-- after a low-volume trust (RT1, only 49 handovers over the
-- whole period) initially ranked near the top purely from
-- statistical noise in its percentage -- a small-sample
-- distortion, not a genuine finding. The threshold was
-- sensitivity-tested at 100/500/1000 and found reasonably
-- stable once genuinely low-volume trusts were excluded.
--
-- AVG(pct_over_30) is used directly (not recalculated from raw
-- counts) after confirming it gives near-identical rankings to
-- the pooled SUM(over_30)/SUM(handover_known) method -- see
-- the old_rank/new_rank comparison query at the bottom.
-- ============================================================

-- --- A) Rate-based ranking ------------------------------------
SELECT
    RANK() OVER (ORDER BY AVG(h.pct_over_30) DESC) AS standard_breach_rank,
    t.trust_code,
    t.trust_name,
    t.region,
    ROUND(AVG(h.pct_over_30), 2) AS avg_pct_over_30,
    ROUND(AVG(h.mean_seconds) / 60.0, 2) AS avg_mean_minutes,
    SUM(h.all_handovers) AS total_handovers_full_period
FROM handovers h
JOIN trusts t ON h.trust_code = t.trust_code
GROUP BY t.trust_code, t.trust_name, t.region
HAVING SUM(h.all_handovers) >= 100
ORDER BY standard_breach_rank;

-- --- B) Impact-based ranking -----------------------------------
-- Uses SUM(over_30) directly -- the exact raw count of patients
-- delayed over 30 minutes -- rather than reconstructing it via
-- SUM(all_handovers * pct_over_30), which introduces a small
-- rounding mismatch (pct_over_30 was calculated against
-- handover_known, not all_handovers).
SELECT TOP 10
    RANK() OVER (ORDER BY SUM(h.over_30) DESC) AS impact_rank,
    t.trust_code,
    t.trust_name,
    t.region,
    ROUND(AVG(h.pct_over_30), 2) AS avg_pct_over_30,
    SUM(h.all_handovers) AS total_handovers_full_period,
    SUM(h.over_30) AS total_delayed_patients_over_30
FROM handovers h
JOIN trusts t ON h.trust_code = t.trust_code
GROUP BY t.trust_code, t.trust_name, t.region
HAVING SUM(h.all_handovers) >= 3000
ORDER BY impact_rank;

-- --- Sensitivity check: does the ranking change meaningfully ---
-- --- depending on the calculation method? ----------------------
-- Compares AVG-of-daily-percentages vs. pooled-totals side by
-- side. Result: ranks differed by at most 1 position across all
-- trusts, confirming the simpler AVG() method is not biased in
-- this dataset.
SELECT
    t.trust_code,
    t.trust_name,
    SUM(h.all_handovers) AS total_handovers,
    ROUND(AVG(h.pct_over_30), 3) AS old_avg_of_daily_pct,
    ROUND(SUM(h.over_30) * 1.0 / NULLIF(SUM(h.handover_known), 0), 3) AS new_true_pooled_pct,
    RANK() OVER (ORDER BY AVG(h.pct_over_30) DESC) AS old_rank,
    RANK() OVER (ORDER BY SUM(h.over_30) * 1.0 / NULLIF(SUM(h.handover_known), 0) DESC) AS new_rank
FROM handovers h
JOIN trusts t ON h.trust_code = t.trust_code
GROUP BY t.trust_code, t.trust_name
HAVING SUM(h.all_handovers) >= 100
ORDER BY new_rank;
