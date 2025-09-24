{{
  config(
    materialized = 'incremental',
    unique_key='uuid',
    on_schema_change='append_new_columns',
    indexes=[
      {'columns': ['uuid'], 'type': 'hash'},
      {'columns': ['from_phone']},
      {'columns': ['carrier']},
    ]
  )
}}

SELECT
  document_metadata.uuid as uuid,
  document_metadata.saved_timestamp,
  to_timestamp((NULLIF(doc->>'reported_date'::text, ''::text)::bigint / 1000)::double precision) AS reported,
  doc->>'from' as from_phone,
  
  CASE 
    WHEN doc->>'from' ~ '^(\+1)?876[8|3|4|5]' THEN 'Digicel'
    WHEN doc->>'from' ~ '^(\+1)?876[9|7|6]' THEN 'Flow'
  END as carrier,
  
  COALESCE(
    doc->'fields'->>'message',
    doc->'fields'->>'sms_message', 
    doc->>'sms_content',
    doc->>'content'
  ) as message_content,
  
  DATE(to_timestamp((NULLIF(doc->>'reported_date'::text, ''::text)::bigint / 1000)::double precision)) as message_date,
  EXTRACT(HOUR FROM to_timestamp((NULLIF(doc->>'reported_date'::text, ''::text)::bigint / 1000)::double precision)) as message_hour,
  EXTRACT(DOW FROM to_timestamp((NULLIF(doc->>'reported_date'::text, ''::text)::bigint / 1000)::double precision)) as day_of_week,
  
  to_timestamp((NULLIF(doc->>'reported_date'::text, ''::text)::bigint / 1000)::double precision) - 
  LAG(to_timestamp((NULLIF(doc->>'reported_date'::text, ''::text)::bigint / 1000)::double precision)) 
  OVER (PARTITION BY doc->>'from' ORDER BY to_timestamp((NULLIF(doc->>'reported_date'::text, ''::text)::bigint / 1000)::double precision)) as time_since_last_message,
  
  CASE
    WHEN doc->>'errors' IS NOT NULL THEN 'processing_error'
    WHEN doc->>'_deleted' = 'true' THEN 'deleted'
    WHEN (
      date_trunc('day', to_timestamp((NULLIF(doc->>'reported_date'::text, ''::text)::bigint / 1000)::double precision)) =
      date_trunc('day', LAG(to_timestamp((NULLIF(doc->>'reported_date'::text, ''::text)::bigint / 1000)::double precision))
        OVER (PARTITION BY doc->>'from' ORDER BY to_timestamp((NULLIF(doc->>'reported_date'::text, ''::text)::bigint / 1000)::double precision)))
      AND (
        to_timestamp((NULLIF(doc->>'reported_date'::text, ''::text)::bigint / 1000)::double precision) -
        LAG(to_timestamp((NULLIF(doc->>'reported_date'::text, ''::text)::bigint / 1000)::double precision))
        OVER (PARTITION BY doc->>'from' ORDER BY to_timestamp((NULLIF(doc->>'reported_date'::text, ''::text)::bigint / 1000)::double precision))
      ) > INTERVAL '8 hours'
    ) THEN 'gap_detected'
    WHEN (
      date_trunc('day', to_timestamp((NULLIF(doc->>'reported_date'::text, ''::text)::bigint / 1000)::double precision)) <>
      date_trunc('day', LAG(to_timestamp((NULLIF(doc->>'reported_date'::text, ''::text)::bigint / 1000)::double precision))
        OVER (PARTITION BY doc->>'from' ORDER BY to_timestamp((NULLIF(doc->>'reported_date'::text, ''::text)::bigint / 1000)::double precision)))
      AND (
        to_timestamp((NULLIF(doc->>'reported_date'::text, ''::text)::bigint / 1000)::double precision) -
        LAG(to_timestamp((NULLIF(doc->>'reported_date'::text, ''::text)::bigint / 1000)::double precision))
        OVER (PARTITION BY doc->>'from' ORDER BY to_timestamp((NULLIF(doc->>'reported_date'::text, ''::text)::bigint / 1000)::double precision))
      ) > INTERVAL '14 hours'
    ) THEN 'gap_detected'
    ELSE 'healthy'
  END as message_health,
  
  doc->>'errors' as error_details

FROM {{ ref('document_metadata') }} document_metadata
INNER JOIN
  {{ source('couchdb', env_var('POSTGRES_TABLE')) }} source_table
  ON source_table._id = document_metadata.uuid
WHERE
  document_metadata.doc_type = 'data_record'
  AND document_metadata._deleted = false
  AND doc->>'from' IN (
    '{{ env_var("MONITORING_PHONE_DIGICEL", "") }}',
    '{{ env_var("MONITORING_PHONE_FLOW", "") }}'
  )
{% if is_incremental() %}
  AND document_metadata.saved_timestamp >= {{ max_existing_timestamp('saved_timestamp') }}
{% endif %}
