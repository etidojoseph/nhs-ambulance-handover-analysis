-- ============================================================
-- 04_q2_lost_hours.sql
-- Q2: What is the real-world impact, in lost ambulance crew hours?
--
-- "Lost hours" = time spent BEYOND the 15-minute NHS standard,
-- not total handover time. Formula: total_hours minus what the
-- time WOULD have been if every known-time handover took exactly
-- 15 minutes (handover_known * 0.25 hours). This matches the
-- methodology used in published NHS/AACE analyses, so the
-- figures here are comparable to those.
-- ============================================================

-- --- Trust-level lost hours ranking -----------------------------
SELECT
    RANK() OVER (ORDER BY SUM(h.total_hours - (h.handover_known * 0.25)) DESC) AS lost_hours_rank,
    t.trust_code,
    t.trust_name,
    t.region,
    ROUND(SUM(h.total_hours), 0) AS total_actual_hours,
    ROUND(SUM(h.total_hours - (h.handover_known * 0.25)), 0) AS lost_hours,
    SUM(h.all_handovers) AS total_handovers_full_period
FROM handovers h
JOIN trusts t ON h.trust_code = t.trust_code
GROUP BY t.trust_code, t.trust_name, t.region
HAVING SUM(h.all_handovers) >= 100
ORDER BY lost_hours_rank;

-- --- Regional breakdown, normalized for trust size --------------
-- lost_hours_per_handover divides out the size effect, so a
-- region with more/bigger trusts doesn't automatically look
-- "worse" just from volume. This confirmed the Midlands/East of
-- England pattern is a genuine rate difference, not a volume
-- artifact (Midlands: 0.577 hrs/handover vs South East: 0.051 --
-- an 11x difference that holds after controlling for size).
SELECT
    t.region,
    SUM(h.total_hours - (h.handover_known * 0.25)) AS total_lost_hours,
    SUM(h.all_handovers) AS total_handovers,
    ROUND(SUM(h.total_hours - (h.handover_known * 0.25)) / SUM(h.all_handovers), 3) AS lost_hours_per_handover
FROM handovers h
JOIN trusts t ON h.trust_code = t.trust_code
GROUP BY t.region
HAVING SUM(h.all_handovers) >= 100
ORDER BY lost_hours_per_handover DESC;
