-- ============================================================
-- Growth & Retention Analysis
-- SQL Queries — CTEs & Window Functions
-- Author: Parichennayapalli Viswa Sai Reddy
-- ============================================================

-- ----------------------------------------------------------------
-- 1. Churn Rate & Retention by Acquisition Channel
-- ----------------------------------------------------------------
WITH channel_stats AS (
    SELECT
        acquisition_channel,
        COUNT(*)                                      AS total_users,
        SUM(churned_month1)                           AS churned_users,
        ROUND(AVG(churned_month1) * 100, 2)          AS churn_rate_pct,
        ROUND(AVG(retained_day30) * 100, 2)          AS d30_retention_pct,
        ROUND(AVG(estimated_ltv), 2)                 AS avg_ltv
    FROM users
    GROUP BY acquisition_channel
)
SELECT *,
    RANK() OVER (ORDER BY churn_rate_pct ASC)        AS retention_rank,
    RANK() OVER (ORDER BY avg_ltv DESC)              AS ltv_rank
FROM channel_stats
ORDER BY churn_rate_pct;

-- ----------------------------------------------------------------
-- 2. Onboarding Drop-off Funnel (Window Function: Cumulative %)
-- ----------------------------------------------------------------
WITH step_cohorts AS (
    SELECT
        onboarding_steps_completed                   AS steps,
        COUNT(*)                                     AS users,
        SUM(churned_month1)                          AS churned,
        ROUND(AVG(churned_month1) * 100, 2)         AS churn_pct,
        ROUND(AVG(retained_day7) * 100, 2)          AS d7_retention,
        ROUND(AVG(retained_day14) * 100, 2)         AS d14_retention,
        ROUND(AVG(retained_day30) * 100, 2)         AS d30_retention
    FROM users
    GROUP BY onboarding_steps_completed
)
SELECT *,
    ROUND(
        SUM(users) OVER (ORDER BY steps DESC) * 100.0
        / SUM(users) OVER (), 1
    )                                                AS cumulative_reached_pct
FROM step_cohorts
ORDER BY steps;

-- ----------------------------------------------------------------
-- 3. Monthly Cohort Acquisition & Retention Trends
-- ----------------------------------------------------------------
WITH cohort_summary AS (
    SELECT
        cohort_month,
        COUNT(*)                                     AS cohort_size,
        SUM(retained_day30)                          AS retained_d30,
        ROUND(AVG(retained_day30) * 100, 2)         AS retention_pct,
        ROUND(AVG(churned_month1) * 100, 2)         AS churn_pct,
        ROUND(AVG(estimated_ltv), 2)                AS avg_ltv
    FROM users
    GROUP BY cohort_month
)
SELECT *,
    ROUND(AVG(retention_pct) OVER (
        ORDER BY cohort_month
        ROWS BETWEEN 2 PRECEDING AND CURRENT ROW
    ), 2)                                            AS rolling_3m_retention,
    ROUND(retention_pct - LAG(retention_pct, 1) OVER (
        ORDER BY cohort_month
    ), 2)                                            AS mom_retention_change
FROM cohort_summary
ORDER BY cohort_month;

-- ----------------------------------------------------------------
-- 4. High-Risk Segment Identification (Plan × City Tier)
-- ----------------------------------------------------------------
SELECT
    plan,
    city_tier,
    COUNT(*)                                         AS users,
    ROUND(AVG(churned_month1) * 100, 2)             AS churn_rate_pct,
    ROUND(AVG(retained_day30) * 100, 2)             AS d30_retention_pct,
    ROUND(AVG(estimated_ltv), 2)                    AS avg_ltv,
    CASE
        WHEN AVG(churned_month1) > 0.45 THEN 'HIGH RISK'
        WHEN AVG(churned_month1) > 0.30 THEN 'MEDIUM RISK'
        ELSE 'LOW RISK'
    END                                              AS risk_segment
FROM users
GROUP BY plan, city_tier
ORDER BY churn_rate_pct DESC;

-- ----------------------------------------------------------------
-- 5. LTV Percentiles by Acquisition Channel
-- ----------------------------------------------------------------
SELECT
    acquisition_channel,
    COUNT(*)                                         AS users,
    ROUND(MIN(estimated_ltv), 2)                    AS ltv_min,
    ROUND(AVG(estimated_ltv), 2)                    AS ltv_avg,
    ROUND(MAX(estimated_ltv), 2)                    AS ltv_max,
    -- Percentile approximation using NTILE
    ROUND(AVG(CASE WHEN ltv_tile <= 25 THEN estimated_ltv END), 2) AS ltv_p25,
    ROUND(AVG(CASE WHEN ltv_tile <= 50 THEN estimated_ltv END), 2) AS ltv_p50,
    ROUND(AVG(CASE WHEN ltv_tile <= 75 THEN estimated_ltv END), 2) AS ltv_p75
FROM (
    SELECT *,
        NTILE(100) OVER (
            PARTITION BY acquisition_channel ORDER BY estimated_ltv
        ) AS ltv_tile
    FROM users
)
GROUP BY acquisition_channel
ORDER BY ltv_avg DESC;

-- ----------------------------------------------------------------
-- 6. Retention Funnel: D7 → D14 → D30 Drop-off Rates
-- ----------------------------------------------------------------
SELECT
    plan,
    COUNT(*)                                         AS total_users,
    ROUND(AVG(retained_day7) * 100, 2)             AS d7_retention,
    ROUND(AVG(retained_day14) * 100, 2)            AS d14_retention,
    ROUND(AVG(retained_day30) * 100, 2)            AS d30_retention,
    ROUND((AVG(retained_day7) - AVG(retained_day14)) * 100, 2)   AS d7_to_d14_dropoff,
    ROUND((AVG(retained_day14) - AVG(retained_day30)) * 100, 2)  AS d14_to_d30_dropoff
FROM users
GROUP BY plan
ORDER BY d30_retention DESC;
