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
  
  -- Simple carrier detection for Jamaica
  CASE 
    WHEN doc->>'from' ~ '^(\+1)?876[8|3|4|5]' THEN 'Digicel'
    WHEN doc->>'from' ~ '^(\+1)?876[9|7|6]' THEN 'Flow'
  END as carrier,
  
  -- Extract message content
  COALESCE(
    doc->'fields'->>'message',
    doc->'fields'->>'sms_message', 
    doc->>'sms_content',
    doc->>'content'
  ) as message_content,
  
  -- Time-based fields for dashboard
  DATE(to_timestamp((NULLIF(doc->>'reported_date'::text, ''::text)::bigint / 1000)::double precision)) as message_date,
  EXTRACT(HOUR FROM to_timestamp((NULLIF(doc->>'reported_date'::text, ''::text)::bigint / 1000)::double precision)) as message_hour,
  EXTRACT(DOW FROM to_timestamp((NULLIF(doc->>'reported_date'::text, ''::text)::bigint / 1000)::double precision)) as day_of_week,
  
  -- Processing delay
  EXTRACT(EPOCH FROM (document_metadata.saved_timestamp - to_timestamp((NULLIF(doc->>'reported_date'::text, ''::text)::bigint / 1000)::double precision)))/60.0 as processing_delay_minutes

FROM {{ ref('document_metadata') }} document_metadata
INNER JOIN
  {{ source('couchdb', env_var('POSTGRES_TABLE')) }} source_table
  ON source_table._id = document_metadata.uuid
WHERE
  document_metadata.doc_type = 'data_record'
  AND document_metadata._deleted = false
  -- Filter for your monitoring phones (set these as environment variables)
  AND doc->>'from' IN (
    '{{ env_var("MONITORING_PHONE_DIGICEL", "") }}',
    '{{ env_var("MONITORING_PHONE_FLOW", "") }}'
  )
{% if is_incremental() %}
  AND document_metadata.saved_timestamp >= {{ max_existing_timestamp('saved_timestamp') }}
{% endif %}
