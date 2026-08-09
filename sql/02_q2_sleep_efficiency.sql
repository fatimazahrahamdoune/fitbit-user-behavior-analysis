/*=========================================================
Q2: Sleep Efficiency Patterns

Research Question:
How efficiently do users sleep relative to the time they
spend in bed, and what differences exist across sleep-
efficiency levels?

Approach:
1. Remove duplicate sleep records.
2. Calculate sleep efficiency for each sleep record.
3. Calculate average sleep efficiency per user.
4. Segment users into analytical efficiency groups.
5. Summarize the final user distribution.
=========================================================*/


/*=========================================================
1. DATA CLEANING
=========================================================*/

/*
Remove duplicate records while preserving one copy of each
unique observation.
*/

DROP TABLE IF EXISTS sleep_day_clean;

CREATE TABLE sleep_day_clean AS
SELECT DISTINCT *
FROM sleep_day;


/*=========================================================
2. FEATURE ENGINEERING
=========================================================*/

/*
Sleep Efficiency =
Total Minutes Asleep / Total Time in Bed * 100

NULLIF prevents division by zero if total_time_in_bed = 0.
*/

DROP TABLE IF EXISTS sleep_day_features;

CREATE TABLE sleep_day_features AS
SELECT
    *,
    ROUND(
        total_minutes_asleep * 100.0
        / NULLIF(total_time_in_bed, 0),
        2
    ) AS sleep_efficiency
FROM sleep_day_clean;


/*=========================================================
3. FEATURE VALIDATION
=========================================================*/

-- Preview the engineered data
SELECT *
FROM sleep_day_features
LIMIT 10;

-- Confirm record count
SELECT
    COUNT(*) AS total_records
FROM sleep_day_features;

-- Review the range of sleep efficiency values
SELECT
    MIN(sleep_efficiency) AS min_efficiency,
    MAX(sleep_efficiency) AS max_efficiency,
    ROUND(AVG(sleep_efficiency), 2) AS avg_efficiency
FROM sleep_day_features;


/*=========================================================
4. AVERAGE SLEEP EFFICIENCY PER USER
=========================================================*/

/*
The research question focuses on user-level behavior rather
than individual nights.

Average sleep efficiency is therefore calculated across all
available sleep records for each user, producing one
representative value per user.
*/

DROP TABLE IF EXISTS avg_sleep_efficiency;

CREATE TABLE avg_sleep_efficiency AS
SELECT
    id,
    ROUND(AVG(sleep_efficiency), 2) AS avg_sleep_efficiency
FROM sleep_day_features
GROUP BY id;


/*=========================================================
5. USER SEGMENTATION
=========================================================*/

/*
Analytical segment definitions:

High Efficiency     = 95% or higher
Moderate Efficiency = 85% to below 95%
Low Efficiency      = below 85%

These thresholds were created for this case study and are
not official Fitbit or clinical sleep-efficiency standards.
*/

DROP TABLE IF EXISTS q2_sleep_analysis;

CREATE TABLE q2_sleep_analysis AS
SELECT
    id,
    avg_sleep_efficiency,
    CASE
        WHEN avg_sleep_efficiency >= 95
            THEN 'High Efficiency'
        WHEN avg_sleep_efficiency >= 85
            THEN 'Moderate Efficiency'
        ELSE 'Low Efficiency'
    END AS efficiency_segment
FROM avg_sleep_efficiency;


/*=========================================================
6. FINAL RESULTS
=========================================================*/

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
