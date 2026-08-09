/*=========================================================
DATA PREPARATION FOR QUESTION 3

Purpose:
Create the integrated hourly and daily datasets used as
the foundation for the activity timing and distribution
analysis in Question 3.
=========================================================*/


/*=========================================================
1. HOURLY ACTIVITY MASTER TABLE
=========================================================*/

/*
Combine hourly steps, calories, and intensity data into
one user-hour level table.
*/

DROP TABLE IF EXISTS hourly_activity_master;

CREATE TABLE hourly_activity_master AS

SELECT
    hs.id,
    hs.activity_hour,
    hs.activity_date,
    hs.hour_of_day,
    hs.step_total,
    hc.calories,
    hi.total_intensity,
    hi.average_intensity

FROM hourly_steps_features AS hs

INNER JOIN hourly_calories_features AS hc
    ON hs.id = hc.id
   AND hs.activity_hour = hc.activity_hour

INNER JOIN hourly_intensities_features AS hi
    ON hs.id = hi.id
   AND hs.activity_hour = hi.activity_hour;


/*=========================================================
2. MASTER TABLE VALIDATION
=========================================================*/

-- Confirm total number of records
SELECT
    COUNT(*) AS total_records
FROM hourly_activity_master;

-- Confirm number of unique users
SELECT
    COUNT(DISTINCT id) AS unique_users
FROM hourly_activity_master;

-- Check for duplicate user-hour combinations
SELECT
    id,
    activity_hour,
    COUNT(*) AS record_count
FROM hourly_activity_master
GROUP BY
    id,
    activity_hour
HAVING COUNT(*) > 1;

-- Check for missing values
SELECT *
FROM hourly_activity_master
WHERE id IS NULL
   OR activity_hour IS NULL
   OR activity_date IS NULL
   OR hour_of_day IS NULL
   OR step_total IS NULL
   OR calories IS NULL
   OR total_intensity IS NULL
   OR average_intensity IS NULL;


/*=========================================================
3. DAILY ACTIVITY METRICS
=========================================================*/

/*
Aggregate hourly records to one row per user-day.

Metrics created:
- total daily steps
- total daily calories
- number of active hours
- average daily intensity
*/

DROP TABLE IF EXISTS daily_activity_metrics;

CREATE TABLE daily_activity_metrics AS

SELECT
    id,
    activity_date,

    SUM(step_total) AS total_daily_steps,

    SUM(calories) AS total_daily_calories,

    COUNT(
        CASE
            WHEN total_intensity > 0 THEN 1
        END
    ) AS active_hours,

    ROUND(
        AVG(average_intensity),
        2
    ) AS average_daily_intensity

FROM hourly_activity_master

GROUP BY
    id,
    activity_date

ORDER BY
    id,
    activity_date;


/*=========================================================
4. DAILY METRICS VALIDATION
=========================================================*/

-- Confirm number of user-day records created
SELECT
    COUNT(*) AS total_records
FROM daily_activity_metrics;

-- Confirm number of unique user-days in hourly source data
SELECT
    COUNT(DISTINCT (id, activity_date)) AS unique_user_days
FROM hourly_activity_master;

-- Compare with cleaned daily activity dataset
SELECT
    COUNT(*) AS daily_activity_clean_records
FROM daily_activity_clean;


/*
Identify user-days that appear in the daily dataset but
are missing from the hourly datasets.
*/

SELECT
    d.id,
    d.activity_date

FROM daily_activity_clean d

LEFT JOIN hourly_activity_master h
    ON d.id = h.id
   AND d.activity_date = h.activity_date

WHERE h.id IS NULL;


/*
Validation Result:

daily_activity_metrics contains 934 user-day records,
compared with 936 records in daily_activity_clean.

Two user-day observations present in the daily activity
dataset are absent from the hourly datasets.

Because daily_activity_metrics is derived exclusively from
hourly records, those observations cannot be included.

The difference therefore reflects a limitation of the
original Fitbit source datasets rather than an error in the
transformation process.
*/
