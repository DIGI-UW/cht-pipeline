{{
  config(
    materialized = 'incremental',
    unique_key='uuid',
    on_schema_change='append_new_columns',
    indexes=[
      {'columns': ['uuid'], 'type': 'hash'},
      {'columns': ['saved_timestamp'], 'type': 'btree'},
    ]
  )
}}
SELECT DISTINCT
    e.uuid,
    e.age,
    e.reported as reported,
    e.vmmc_no,
    e.enrollment_facility,
    e.saved_timestamp,
    CASE 
        WHEN j1.form = '1' THEN 'Potential AE' 
        WHEN j1.form = '0' THEN 'NO AE' 
        WHEN j1.form IS NULL AND j1.message IS NOT NULL THEN 'FREE SMS'
        ELSE 'NO SMS'
    END AS day_1,
    CASE 
       WHEN j2.form = '1' THEN 'Potential AE' 
        WHEN j2.form = '0' THEN 'NO AE' 
        WHEN j2.form IS NULL AND j2.message IS NOT NULL THEN 'FREE SMS'
        ELSE 'NO SMS'
    END AS day_2,
    CASE 
        WHEN j3.form = '1' THEN 'Potential AE' 
        WHEN j3.form = '0' THEN 'NO AE' 
        WHEN j3.form IS NULL AND j3.message IS NOT NULL THEN 'FREE SMS'
        ELSE 'NO SMS'
    END AS day_3,
    CASE 
        WHEN j4.form = '1' THEN 'Potential AE' 
        WHEN j4.form = '0' THEN 'NO AE' 
        WHEN j4.form IS NULL AND j4.message IS NOT NULL THEN 'FREE SMS'
        ELSE 'NO SMS'
    END AS day_4,
    CASE 
        WHEN j5.form = '1' THEN 'Potential AE' 
        WHEN j5.form = '0' THEN 'NO AE' 
        WHEN j5.form IS NULL AND j5.message IS NOT NULL THEN 'FREE SMS'
        ELSE 'NO SMS'
    END AS day_5,
    CASE 
        WHEN j6.form = '1' THEN 'Potential AE' 
        WHEN j6.form = '0' THEN 'NO AE' 
        WHEN j6.form IS NULL AND j6.message IS NOT NULL THEN 'FREE SMS'
        ELSE 'NO SMS'
    END AS day_6,
    CASE 
        WHEN j7.form = '1' THEN 'Potential AE' 
        WHEN j7.form = '0' THEN 'NO AE' 
        WHEN j7.form IS NULL AND j7.message IS NOT NULL THEN 'FREE SMS'
        ELSE 'NO SMS'
    END AS day_7,
    CASE 
       WHEN j8.form = '1' THEN 'Potential AE' 
        WHEN j8.form = '0' THEN 'NO AE' 
        WHEN j8.form IS NULL AND j8.message IS NOT NULL THEN 'FREE SMS'
        ELSE 'NO SMS'
    END AS day_8,
    CASE 
        WHEN j9.form = '1' THEN 'Potential AE' 
        WHEN j9.form = '0' THEN 'NO AE' 
        WHEN j9.form IS NULL AND j9.message IS NOT NULL THEN 'FREE SMS'
        ELSE 'NO SMS'
    END AS day_9,
    CASE 
        WHEN j10.form = '1' THEN 'Potential AE' 
        WHEN j10.form = '0' THEN 'NO AE' 
        WHEN j10.form IS NULL AND j10.message IS NOT NULL THEN 'FREE SMS'
        ELSE 'NO SMS'
    END AS day_10,
    CASE 
        WHEN j11.form = '1' THEN 'Potential AE' 
        WHEN j11.form = '0' THEN 'NO AE' 
        WHEN j11.form IS NULL AND j11.message IS NOT NULL THEN 'FREE SMS'
        ELSE 'NO SMS'
    END AS day_11,
    CASE 
       WHEN j12.form = '1' THEN 'Potential AE' 
        WHEN j12.form = '0' THEN 'NO AE' 
        WHEN j12.form IS NULL AND j12.message IS NOT NULL THEN 'FREE SMS'
        ELSE 'NO SMS'
    END AS day_12,
    CASE 
        WHEN j13.form = '1' THEN 'Potential AE' 
        WHEN j13.form = '0' THEN 'NO AE' 
        WHEN j13.form IS NULL AND j13.message IS NOT NULL THEN 'FREE SMS'
        ELSE 'NO SMS'
    END AS day_13
FROM 
    {{ ref('patient') }} e
LEFT JOIN
(
    SELECT 
        dr.uuid,
        dr.reported::date AS reported,
        dr.message AS message,
        dr.form AS form
    FROM 
        {{ ref('message') }} dr
) j1 ON e.uuid = j1.uuid AND e.reported::date + interval '1 day' = j1.reported::date
LEFT JOIN
(
    SELECT 
        dr.uuid,
        dr.reported::date AS reported,
        dr.message AS message,
        dr.form AS form
    FROM 
        {{ ref('message') }} dr
) j2 ON e.uuid = j2.uuid AND e.reported::date + interval '2 days' = j2.reported::date
LEFT JOIN
(
    SELECT 
        dr.uuid,
        dr.reported::date AS reported,
        dr.message AS message,
        dr.form AS form
    FROM 
        {{ ref('message') }} dr
) j3 ON e.uuid = j3.uuid AND e.reported::date + interval '3 days' = j3.reported::date
LEFT JOIN
(
    SELECT 
        dr.uuid,
        dr.reported::date AS reported,
        dr.message AS message,
        dr.form AS form
    FROM 
        {{ ref('message') }} dr
) j4 ON e.uuid = j4.uuid AND e.reported::date + interval '4 days' = j4.reported::date
LEFT JOIN
(
    SELECT 
        dr.uuid,
        dr.reported::date AS reported,
        dr.message AS message,
        dr.form AS form
    FROM 
        {{ ref('message') }} dr
) j5 ON e.uuid = j5.uuid AND e.reported::date + interval '5 days' = j5.reported::date
LEFT JOIN
(
    SELECT 
        dr.uuid,
        dr.reported::date AS reported,
        dr.message AS message,
        dr.form AS form
    FROM 
        {{ ref('message') }} dr
) j6 ON e.uuid = j6.uuid AND e.reported::date + interval '6 days' = j6.reported::date
LEFT JOIN
(
    SELECT 
        dr.uuid,
        dr.reported::date AS reported,
        dr.message AS message,
        dr.form AS form
    FROM 
        {{ ref('message') }} dr
) j7 ON e.uuid = j7.uuid AND e.reported::date + interval '7 days' = j7.reported::date
LEFT JOIN
(
    SELECT 
        dr.uuid,
        dr.reported::date AS reported,
        dr.message AS message,
        dr.form AS form
    FROM 
        {{ ref('message') }} dr
) j8 ON e.uuid = j8.uuid AND e.reported::date + interval '8 days' = j8.reported::date
LEFT JOIN
(
    SELECT 
        dr.uuid,
        dr.reported::date AS reported,
        dr.message AS message,
        dr.form AS form
    FROM 
        {{ ref('message') }} dr
) j9 ON e.uuid = j9.uuid AND e.reported::date + interval '9 days' = j9.reported::date
LEFT JOIN
(
    SELECT 
        dr.uuid,
        dr.reported::date AS reported,
        dr.message AS message,
        dr.form AS form
    FROM 
        {{ ref('message') }} dr
) j10 ON e.uuid = j10.uuid AND e.reported::date + interval '10 days' = j10.reported::date
LEFT JOIN
(
    SELECT 
        dr.uuid,
        dr.reported::date AS reported,
        dr.message AS message,
        dr.form AS form
    FROM 
        {{ ref('message') }} dr
) j11 ON e.uuid = j11.uuid AND e.reported::date + interval '11 days' = j11.reported::date
LEFT JOIN
(
    SELECT 
        dr.uuid,
        dr.reported::date AS reported,
        dr.message AS message,
        dr.form AS form
    FROM 
        {{ ref('message') }} dr
) j12 ON e.uuid = j12.uuid AND e.reported::date + interval '12 days' = j12.reported::date
LEFT JOIN
(
    SELECT 
        dr.uuid,
        dr.reported::date AS reported,
        dr.message AS message,
        dr.form AS form
    FROM 
        {{ ref('message') }} dr
) j13 ON e.uuid = j13.uuid AND e.reported::date + interval '13 days' = j13.reported::date