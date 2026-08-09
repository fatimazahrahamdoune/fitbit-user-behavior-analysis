/*=========================================================
Q1: Weekday vs. Weekend Activity Patterns

Research Question:
Are users consistent in their activity habits, or do some
primarily concentrate their activity on weekends?

Approach:
1. Investigate and clean anomalous daily activity records.
2. Create weekday/weekend features.
3. Calculate average weekday and weekend steps per user.
4. Validate user coverage.
5. Segment users based on their weekend-to-weekday activity ratio.
=========================================================*/


/*=========================================================
1. DATA CLEANING
=========================================================*/

-- Review zero-step records
SELECT *
FROM daily_activity
WHERE total_steps = 0;

-- Check whether zero-step days also contain zero calories
SELECT
    COUNT(*) AS zero_step_zero_calories
FROM daily_activity
WHERE total_steps = 0
  AND calories = 0;

-- Check whether zero-step days contain no recorded activity
SELECT
    COUNT(*) AS zero_activity_records
FROM daily_activity
WHERE total_steps = 0
  AND very_active_minutes = 0
  AND fairly_active_minutes = 0
  AND lightly_active_minutes = 0;

-- Check sedentary time for zero-step days
SELECT
    COUNT(*) AS zero_step_with_sedentary_time
FROM daily_activity
WHERE total_steps = 0
  AND sedentary_minutes > 0;

/*
Cleaning Decision:
Four records contained 0 calories and 1,440 sedentary minutes.
Because 0 calories over a full 24-hour day is not physiologically
plausible, these records were treated as data anomalies and removed.

The four records represented approximately 0.4% of the dataset.
*/

DROP TABLE IF EXISTS daily_activity_clean;

CREATE TABLE daily_activity_clean AS
SELECT *
FROM daily_activity
WHERE NOT (
    calories = 0
    AND sedentary_minutes = 1440
);


/*=========================================================
2. FEATURE ENGINEERING
=========================================================*/

/*
Create weekday/weekend variables that are not available
in the original Fitbit dataset.
*/

DROP TABLE IF EXISTS daily_activity_features;

CREATE TABLE daily_activity_features AS
SELECT
    *,
    TRIM(TO_CHAR(activity_date, 'Day')) AS day_name,
    CASE
        WHEN TRIM(TO_CHAR(activity_date, 'Day'))
             IN ('Saturday', 'Sunday')
            THEN 'Weekend'
        ELSE 'Weekday'
    END AS day_type
FROM daily_activity_clean;

-- Verify the new features
SELECT
    activity_date,
    day_name,
    day_type
FROM daily_activity_features
LIMIT 10;


/*=========================================================
3. WEEKDAY VS. WEEKEND ACTIVITY
=========================================================*/

/*
Calculate each user's average weekday and weekend steps,
then calculate the weekend-to-weekday activity ratio.

A ratio above 1 means average weekend activity is higher.
A ratio below 1 means average weekday activity is higher.
*/

SELECT
    wkd.id,
    wkd.avg_weekday_steps,
    wke.avg_weekend_steps,
    ROUND(
        wke.avg_weekend_steps / wkd.avg_weekday_steps,
        2
    ) AS weekend_ratio
FROM
(
    SELECT
        id,
        ROUND(AVG(total_steps), 2) AS avg_weekday_steps
    FROM daily_activity_features
    WHERE day_type = 'Weekday'
    GROUP BY id
) AS wkd

INNER JOIN

(
    SELECT
        id,
        ROUND(AVG(total_steps), 2) AS avg_weekend_steps
    FROM daily_activity_features
    WHERE day_type = 'Weekend'
    GROUP BY id
) AS wke

ON wkd.id = wke.id
ORDER BY weekend_ratio DESC;


/*=========================================================
4. DATA VALIDATION
=========================================================*/

/*
The comparison returned 32 users even though the dataset
contains 33 unique users. The following checks identify
users missing either weekday or weekend observations.
*/

-- Users with weekday records but no weekend records
SELECT DISTINCT id
FROM daily_activity_features
WHERE day_type = 'Weekday'

EXCEPT

SELECT DISTINCT id
FROM daily_activity_features
WHERE day_type = 'Weekend';


-- Users with weekend records but no weekday records
SELECT DISTINCT id
FROM daily_activity_features
WHERE day_type = 'Weekend'

EXCEPT

SELECT DISTINCT id
FROM daily_activity_features
WHERE day_type = 'Weekday';

/*
Validation Result:
User 4057192912 has weekday records but no weekend records.

Therefore, 32 of the 33 users are included in the weekday/weekend
comparison. The exclusion is expected because calculating a
weekend-to-weekday ratio requires observations from both periods.
*/


/*=========================================================
5. USER SEGMENTATION
=========================================================*/

/*
Segment definitions:

Weekend Warrior  = weekend ratio >= 1.20
Consistent Mover = weekend ratio between 0.80 and 1.19
Weekday Active   = weekend ratio < 0.80

These thresholds are analytical definitions created for
this case study and are not official Fitbit classifications.
*/

DROP TABLE IF EXISTS q1_weekend_analysis;

CREATE TABLE q1_weekend_analysis AS
SELECT
    *,
    CASE
        WHEN weekend_ratio >= 1.20
            THEN 'Weekend Warrior'
        WHEN weekend_ratio >= 0.80
             AND weekend_ratio < 1.20
            THEN 'Consistent Mover'
        ELSE 'Weekday Active'
    END AS user_segment
FROM
(
    SELECT
        wkd.id,
        wkd.avg_weekday_steps,
        wke.avg_weekend_steps,
        ROUND(
            wke.avg_weekend_steps / wkd.avg_weekday_steps,
            2
        ) AS weekend_ratio
    FROM
    (
        SELECT
            id,
            ROUND(AVG(total_steps), 2) AS avg_weekday_steps
        FROM daily_activity_features
        WHERE day_type = 'Weekday'
        GROUP BY id
    ) AS wkd

    INNER JOIN

    (
        SELECT
            id,
            ROUND(AVG(total_steps), 2) AS avg_weekend_steps
        FROM daily_activity_features
        WHERE day_type = 'Weekend'
        GROUP BY id
    ) AS wke

    ON wkd.id = wke.id
) AS weekend_analysis;


/*=========================================================
6. FINAL RESULTS
=========================================================*/

-- Number and percentage of users in each segment
SELECT
    user_segment,
    COUNT(*) AS number_of_users,
    ROUND(
        COUNT(*) * 100.0 /
        (SELECT COUNT(*) FROM q1_weekend_analysis),
        1
    ) AS percentage_of_users
FROM q1_weekend_analysis
GROUP BY user_segment
ORDER BY number_of_users DESC;
