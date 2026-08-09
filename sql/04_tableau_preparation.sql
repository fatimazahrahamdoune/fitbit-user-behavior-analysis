/*=========================================================
TABLEAU PREPARATION

Purpose:
Create visualization-ready datasets for the three research
questions analyzed in this project.

These tables are derived from the final analysis tables and
are structured specifically to simplify Tableau visualization.

Contents:
1. Q1 - Weekday vs. Weekend Activity
2. Q2 - Sleep Efficiency
3. Q3 - Activity Timing & Distribution
=========================================================*/


/*=========================================================
1. Q1 - WEEKDAY VS. WEEKEND ACTIVITY
=========================================================*/


/*---------------------------------------------------------
Q1 Tableau Summary

Purpose:
Create a compact summary showing the number and percentage
of users in each activity segment.
---------------------------------------------------------*/

DROP TABLE IF EXISTS q1_tableau_summary;

CREATE TABLE q1_tableau_summary AS

SELECT
    user_segment,
    COUNT(*) AS number_of_users,
    ROUND(
        COUNT(*) * 100.0
        / (SELECT COUNT(*) FROM q1_weekend_analysis),
        1
    ) AS percentage_of_users

FROM q1_weekend_analysis

GROUP BY user_segment

ORDER BY number_of_users DESC;


-- Validate Q1 Tableau Summary
SELECT *
FROM q1_tableau_summary;


/*---------------------------------------------------------
Q1 User-Level Activity Dataset

Purpose:
Provide user-level weekday and weekend activity metrics for
the scatter plot comparing average weekday and weekend steps.
---------------------------------------------------------*/

DROP TABLE IF EXISTS q1_tableau_user_activity;

CREATE TABLE q1_tableau_user_activity AS

SELECT
    id,
    avg_weekday_steps,
    avg_weekend_steps,
    weekend_ratio,
    user_segment

FROM q1_weekend_analysis;


-- Validate Q1 User-Level Dataset
SELECT
    COUNT(*) AS number_of_users,
    MIN(weekend_ratio) AS min_weekend_ratio,
    MAX(weekend_ratio) AS max_weekend_ratio

FROM q1_tableau_user_activity;


/*=========================================================
2. Q2 - SLEEP EFFICIENCY
=========================================================*/


/*---------------------------------------------------------
Q2 Tableau Summary

Purpose:
Create a compact summary showing the number and percentage
of users in each sleep-efficiency segment.
---------------------------------------------------------*/

DROP TABLE IF EXISTS q2_tableau_summary;

CREATE TABLE q2_tableau_summary AS

SELECT
    efficiency_segment,
    COUNT(*) AS number_of_users,
    ROUND(
        COUNT(*) * 100.0
        / (SELECT COUNT(*) FROM q2_sleep_analysis),
        1
    ) AS percentage_of_users

FROM q2_sleep_analysis

GROUP BY efficiency_segment

ORDER BY number_of_users DESC;


-- Validate Q2 Tableau Summary
SELECT *
FROM q2_tableau_summary;


/*---------------------------------------------------------
Q2 User-Level Sleep Efficiency Dataset

Purpose:
Provide one average sleep-efficiency value per user for the
individual sleep-efficiency visualization.
---------------------------------------------------------*/

DROP TABLE IF EXISTS q2_tableau_user_efficiency;

CREATE TABLE q2_tableau_user_efficiency AS

SELECT
    id,
    avg_sleep_efficiency,
    efficiency_segment

FROM q2_sleep_analysis;


-- Validate Q2 User-Level Dataset
SELECT
    COUNT(*) AS number_of_users,
    MIN(avg_sleep_efficiency) AS minimum_efficiency,
    MAX(avg_sleep_efficiency) AS maximum_efficiency

FROM q2_tableau_user_efficiency;


/*=========================================================
3. Q3 - ACTIVITY TIMING & DISTRIBUTION
=========================================================*/


/*---------------------------------------------------------
Q3 Hourly Tableau Dataset

Purpose:
Create an hourly visualization-ready dataset combining
activity timing with daily activity metrics.

This dataset supports analysis of:
- average hourly steps
- average intensity
- time-of-day activity patterns
- daily activity-volume groups
---------------------------------------------------------*/

DROP TABLE IF EXISTS q3_tableau_data;

CREATE TABLE q3_tableau_data AS

SELECT
    h.id,
    h.activity_hour,
    h.activity_date,
    h.hour_of_day,
    h.step_total,
    h.calories AS hourly_calories,
    h.total_intensity,
    h.average_intensity,

    d.total_daily_steps,
    d.total_daily_calories,
    d.active_hours,
    d.average_daily_intensity,

    CASE
        WHEN d.total_daily_steps < 5000
            THEN 'Low Activity'
        WHEN d.total_daily_steps BETWEEN 5000 AND 9999
            THEN 'Moderate Activity'
        ELSE 'High Activity'
    END AS step_volume_group,

    CASE
        WHEN h.hour_of_day BETWEEN 6 AND 11
            THEN 'Morning'
        WHEN h.hour_of_day BETWEEN 12 AND 16
            THEN 'Afternoon'
        WHEN h.hour_of_day BETWEEN 17 AND 20
            THEN 'Evening'
        ELSE 'Night'
    END AS time_of_day

FROM hourly_activity_master h

INNER JOIN daily_activity_metrics d
    ON h.id = d.id
   AND h.activity_date = d.activity_date

WHERE d.total_daily_steps > 0;


-- Validate Q3 Hourly Tableau Dataset
SELECT
    COUNT(*) AS total_records,
    COUNT(DISTINCT id) AS unique_users,
    COUNT(DISTINCT (id, activity_date)) AS unique_user_days

FROM q3_tableau_data;


-- Validate Activity by Time of Day
SELECT
    time_of_day,
    ROUND(AVG(step_total), 2) AS avg_hourly_steps,
    ROUND(AVG(total_intensity), 2) AS avg_intensity

FROM q3_tableau_data

GROUP BY time_of_day;


/*---------------------------------------------------------
Q3 Distribution Tableau Dataset

Purpose:
Create a summarized dataset for comparing More Concentrated
and More Distributed activity within similar step volumes.

Daily activity is grouped into 1,000-step ranges. Within
each range, the median number of active hours is used to
classify each day as More Distributed or More Concentrated.

Only groups containing at least 10 user-days are retained
to support more stable visual comparisons.
---------------------------------------------------------*/

DROP TABLE IF EXISTS q3_distribution_tableau;

CREATE TABLE q3_distribution_tableau AS

WITH activity_data AS (

    SELECT
        id,
        activity_date,
        total_daily_steps,
        total_daily_calories,
        active_hours,

        FLOOR(total_daily_steps / 1000.0) * 1000
            AS step_range_start

    FROM daily_activity_metrics

    WHERE total_daily_steps > 0
),

range_medians AS (

    SELECT
        step_range_start,

        PERCENTILE_CONT(0.5)
            WITHIN GROUP (ORDER BY active_hours)
            AS median_active_hours

    FROM activity_data

    GROUP BY step_range_start
),

distribution_data AS (

    SELECT
        a.*,

        CASE
            WHEN a.active_hours > m.median_active_hours
                THEN 'More Distributed'
            ELSE 'More Concentrated'
        END AS distribution_type

    FROM activity_data a

    INNER JOIN range_medians m
        ON a.step_range_start = m.step_range_start
),

group_summary AS (

    SELECT
        step_range_start,
        distribution_type,
        COUNT(*) AS number_of_days,
        ROUND(AVG(total_daily_steps), 2) AS avg_daily_steps,
        ROUND(AVG(active_hours), 2) AS avg_active_hours,
        ROUND(AVG(total_daily_calories), 2) AS avg_daily_calories

    FROM distribution_data

    GROUP BY
        step_range_start,
        distribution_type
)

SELECT *
FROM group_summary

WHERE number_of_days >= 10

ORDER BY
    step_range_start,
    distribution_type;


-- Validate Q3 Distribution Tableau Dataset
SELECT
    COUNT(*) AS total_records,
    MIN(step_range_start) AS min_step_range,
    MAX(step_range_start) AS max_step_range

FROM q3_distribution_tableau;
