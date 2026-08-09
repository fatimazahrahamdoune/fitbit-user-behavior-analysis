/*=========================================================
Q3: Activity Timing & Distribution Patterns

Research Question:
How do the timing and distribution of activity throughout
the day relate to user outcomes?

This analysis uses two previously prepared tables:

- hourly_activity_master
- daily_activity_metrics

Approach:
1. Segment days by total activity volume.
2. Evaluate active hours as a distribution measure.
3. Analyze activity across periods of the day.
4. Compare timing patterns across activity-volume groups.
5. Compare concentrated and distributed activity.
6. Control activity volume using 1,000-step ranges.
7. Compare calorie outcomes within comparable ranges.
=========================================================*/


/*=========================================================
1. ACTIVITY VOLUME SEGMENTATION
=========================================================*/

SELECT
    id,
    activity_date,
    total_daily_steps,
    active_hours,
    total_daily_calories,
    average_daily_intensity,

    CASE
        WHEN total_daily_steps < 5000
            THEN 'Low Activity'
        WHEN total_daily_steps BETWEEN 5000 AND 9999
            THEN 'Moderate Activity'
        ELSE 'High Activity'
    END AS step_volume_group

FROM daily_activity_metrics
WHERE total_daily_steps > 0;


/*=========================================================
2. VALIDATE ZERO-STEP RECORDS
=========================================================*/

-- Confirm total daily records
SELECT
    COUNT(*) AS total_daily_records
FROM daily_activity_metrics;

-- Confirm that no positive-step days have zero active hours
SELECT *
FROM daily_activity_metrics
WHERE total_daily_steps > 0
  AND active_hours = 0;

-- Count zero-step days
SELECT
    COUNT(*) AS zero_step_days
FROM daily_activity_metrics
WHERE total_daily_steps = 0;


/*=========================================================
3. STEP-VOLUME DISTRIBUTION
=========================================================*/

SELECT
    step_volume_group,
    COUNT(*) AS number_of_days,
    ROUND(
        COUNT(*) * 100.0 / SUM(COUNT(*)) OVER (),
        1
    ) AS percentage_of_days
FROM
(
    SELECT
        CASE
            WHEN total_daily_steps < 5000
                THEN 'Low Activity'
            WHEN total_daily_steps BETWEEN 5000 AND 9999
                THEN 'Moderate Activity'
            ELSE 'High Activity'
        END AS step_volume_group
    FROM daily_activity_metrics
    WHERE total_daily_steps > 0
) AS volume_groups

GROUP BY step_volume_group
ORDER BY number_of_days DESC;


/*=========================================================
4. ACTIVE HOURS BY ACTIVITY VOLUME
=========================================================*/

SELECT
    step_volume_group,
    MIN(active_hours) AS min_active_hours,
    MAX(active_hours) AS max_active_hours,
    ROUND(AVG(active_hours), 2) AS avg_active_hours
FROM
(
    SELECT
        active_hours,
        CASE
            WHEN total_daily_steps < 5000
                THEN 'Low Activity'
            WHEN total_daily_steps BETWEEN 5000 AND 9999
                THEN 'Moderate Activity'
            ELSE 'High Activity'
        END AS step_volume_group
    FROM daily_activity_metrics
    WHERE total_daily_steps > 0
) AS volume_groups

GROUP BY step_volume_group
ORDER BY avg_active_hours;


/*=========================================================
5. EVALUATE ACTIVITY WINDOW
=========================================================*/

/*
Activity window measures the time between a day's first
and last recorded active hour.
*/

SELECT
    id,
    activity_date,

    MIN(hour_of_day)
        FILTER (WHERE total_intensity > 0)
        AS first_active_hour,

    MAX(hour_of_day)
        FILTER (WHERE total_intensity > 0)
        AS last_active_hour,

    MAX(hour_of_day)
        FILTER (WHERE total_intensity > 0)
    -
    MIN(hour_of_day)
        FILTER (WHERE total_intensity > 0)
        AS activity_window_hours

FROM hourly_activity_master

GROUP BY
    id,
    activity_date

ORDER BY
    id,
    activity_date;


-- Check activity recorded around the boundaries of the day
SELECT
    hour_of_day,
    COUNT(*) AS number_of_records,
    ROUND(AVG(step_total), 2) AS avg_steps,
    ROUND(AVG(total_intensity), 2) AS avg_intensity
FROM hourly_activity_master
WHERE hour_of_day IN (0, 23)
GROUP BY hour_of_day
ORDER BY hour_of_day;

/*
Metric Decision:

Small amounts of activity were recorded at both midnight
and 11 PM. As a result, activity_window_hours could span
almost the entire day even when meaningful activity was
not widely distributed.

Therefore, activity window was not used as the primary
distribution measure. Active hours were retained instead.
*/


/*=========================================================
6. ACTIVITY BY TIME OF DAY
=========================================================*/

SELECT
    CASE
        WHEN h.hour_of_day BETWEEN 6 AND 11
            THEN 'Morning'
        WHEN h.hour_of_day BETWEEN 12 AND 16
            THEN 'Afternoon'
        WHEN h.hour_of_day BETWEEN 17 AND 20
            THEN 'Evening'
        ELSE 'Night'
    END AS time_of_day,

    ROUND(AVG(h.step_total), 2) AS avg_hourly_steps,
    ROUND(AVG(h.total_intensity), 2) AS avg_intensity

FROM hourly_activity_master h

INNER JOIN daily_activity_metrics d
    ON h.id = d.id
   AND h.activity_date = d.activity_date

WHERE d.total_daily_steps > 0

GROUP BY
    CASE
        WHEN h.hour_of_day BETWEEN 6 AND 11
            THEN 'Morning'
        WHEN h.hour_of_day BETWEEN 12 AND 16
            THEN 'Afternoon'
        WHEN h.hour_of_day BETWEEN 17 AND 20
            THEN 'Evening'
        ELSE 'Night'
    END;


/*
Finding:
Activity was highest during the evening, followed closely
by the afternoon. Morning activity was lower, while
nighttime activity was substantially lower.
*/


/*=========================================================
7. ACTIVITY TIMING BY STEP-VOLUME GROUP
=========================================================*/

SELECT
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
    END AS time_of_day,

    ROUND(AVG(h.step_total), 2) AS avg_hourly_steps,
    ROUND(AVG(h.total_intensity), 2) AS avg_intensity

FROM hourly_activity_master h

INNER JOIN daily_activity_metrics d
    ON h.id = d.id
   AND h.activity_date = d.activity_date

WHERE d.total_daily_steps > 0

GROUP BY
    step_volume_group,
    time_of_day

ORDER BY
    step_volume_group,
    time_of_day;


/*
Finding:
All three activity-volume groups followed broadly similar
timing patterns. Nighttime activity was consistently lowest,
while stronger activity generally occurred later in the day.

Higher-volume days therefore appeared to involve more
activity within the same main active periods rather than a
completely different daily schedule.
*/


/*=========================================================
8. MEDIAN ACTIVE HOURS BY ACTIVITY VOLUME
=========================================================*/

SELECT
    step_volume_group,

    PERCENTILE_CONT(0.5)
        WITHIN GROUP (ORDER BY active_hours)
        AS median_active_hours

FROM
(
    SELECT
        active_hours,

        CASE
            WHEN total_daily_steps < 5000
                THEN 'Low Activity'
            WHEN total_daily_steps BETWEEN 5000 AND 9999
                THEN 'Moderate Activity'
            ELSE 'High Activity'
        END AS step_volume_group

    FROM daily_activity_metrics

    WHERE total_daily_steps > 0
) AS volume_groups

GROUP BY step_volume_group
ORDER BY step_volume_group;


/*=========================================================
9. DISTRIBUTION WITHIN ACTIVITY-VOLUME GROUPS
=========================================================*/

/*
Within each activity-volume group, days with active hours
above that group's median are classified as More Distributed.

Days at or below the median are classified as
More Concentrated.
*/

WITH activity_groups AS (

    SELECT
        *,

        CASE
            WHEN total_daily_steps < 5000
                THEN 'Low Activity'
            WHEN total_daily_steps BETWEEN 5000 AND 9999
                THEN 'Moderate Activity'
            ELSE 'High Activity'
        END AS step_volume_group

    FROM daily_activity_metrics

    WHERE total_daily_steps > 0
),

group_medians AS (

    SELECT
        step_volume_group,

        PERCENTILE_CONT(0.5)
            WITHIN GROUP (ORDER BY active_hours)
            AS median_active_hours

    FROM activity_groups

    GROUP BY step_volume_group
),

distribution_groups AS (

    SELECT
        a.*,

        CASE
            WHEN a.active_hours > m.median_active_hours
                THEN 'More Distributed'
            ELSE 'More Concentrated'
        END AS distribution_type

    FROM activity_groups a

    INNER JOIN group_medians m
        ON a.step_volume_group = m.step_volume_group
)

SELECT
    step_volume_group,
    distribution_type,
    COUNT(*) AS number_of_days,
    ROUND(AVG(total_daily_steps), 2) AS avg_daily_steps,
    ROUND(AVG(active_hours), 2) AS avg_active_hours,
    ROUND(AVG(total_daily_calories), 2) AS avg_daily_calories

FROM distribution_groups

GROUP BY
    step_volume_group,
    distribution_type

ORDER BY
    step_volume_group,
    distribution_type;


/*
Initial Finding:

The relationship between distribution and calorie
expenditure varied across broad step-volume groups.

Because average daily steps still differed meaningfully
between some concentrated and distributed groups, a
narrower activity-volume comparison was required.
*/


/*=========================================================
10. CONTROL ACTIVITY VOLUME USING 1,000-STEP RANGES
=========================================================*/

/*
Days are grouped into 1,000-step ranges to compare activity
distribution among days with more similar total activity
volume.

Only distribution groups containing at least 10 user-days
are retained.
*/

WITH activity_data AS (

    SELECT
        *,
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
)

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

HAVING COUNT(*) >= 10

ORDER BY
    step_range_start,
    distribution_type;


/*=========================================================
11. FINAL DISTRIBUTION VS. CALORIE COMPARISON
=========================================================*/

WITH activity_data AS (

    SELECT
        *,
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
        AVG(total_daily_calories) AS avg_calories

    FROM distribution_data

    GROUP BY
        step_range_start,
        distribution_type
),

comparable_ranges AS (

    SELECT
        step_range_start,

        MAX(
            CASE
                WHEN distribution_type = 'More Concentrated'
                    THEN avg_calories
            END
        ) AS concentrated_calories,

        MAX(
            CASE
                WHEN distribution_type = 'More Distributed'
                    THEN avg_calories
            END
        ) AS distributed_calories

    FROM group_summary

    WHERE number_of_days >= 10

    GROUP BY step_range_start

    -- Keep only ranges containing both distribution types
    HAVING COUNT(*) = 2
)

SELECT
    COUNT(*) AS comparable_step_ranges,

    COUNT(*) FILTER (
        WHERE distributed_calories > concentrated_calories
    ) AS ranges_where_distributed_is_higher,

    COUNT(*) FILTER (
        WHERE concentrated_calories > distributed_calories
    ) AS ranges_where_concentrated_is_higher

FROM comparable_ranges;


/*
Final Finding:

Across 16 comparable step ranges:

- More Distributed activity had higher average calories
  in 9 ranges.

- More Concentrated activity had higher average calories
  in 7 ranges.

Because the results were relatively balanced, neither
distribution pattern consistently corresponded with higher
calorie expenditure after daily step volume was more closely
controlled.

Overall activity volume may therefore play a larger role
than activity distribution, although further analysis would
be required to establish that relationship.
*/
