{{
  config(
    materialized = 'incremental',
    unique_key='uuid',
    on_schema_change='append_new_columns',
    indexes=[
      {'columns': ['uuid'], 'type': 'hash'},
      {'columns': ['from_phone']},
      {'columns': ['message_timestamp']},
      {'columns': ['message_health']},
    ],
    post_hook="
      DO $$
      DECLARE
        record_count INTEGER;
        phone_numbers TEXT;
      BEGIN
        SELECT COUNT(*) INTO record_count FROM {{ this }};
        SELECT STRING_AGG(DISTINCT from_phone, ', ') INTO phone_numbers 
        FROM {{ this }};
        
        RAISE NOTICE '=== MONITORING MESSAGES PROCESSING COMPLETE ===';
        RAISE NOTICE 'Total records processed: %', record_count;
        RAISE NOTICE 'Phone numbers found: %', COALESCE(phone_numbers, 'NONE');
        RAISE NOTICE '==============================================';
      END $$;
    "
  )
}}

-- Logging configuration for debugging
{{ log("=== MONITORING MESSAGES MODEL CONFIGURATION ===", info=true) }}
{{ log("MONITORING_PHONE_DIGICEL: " ~ env_var("MONITORING_PHONE_DIGICEL", "NOT_SET"), info=true) }}
{{ log("MONITORING_PHONE_FLOW: " ~ env_var("MONITORING_PHONE_FLOW", "NOT_SET"), info=true) }}
{{ log("POSTGRES_TABLE: " ~ env_var("POSTGRES_TABLE", "NOT_SET"), info=true) }}
{{ log("POSTGRES_SCHEMA: " ~ env_var("POSTGRES_SCHEMA", "NOT_SET"), info=true) }}
{{ log("================================================", info=true) }}
SELECT
  document_metadata.uuid as uuid,
  document_metadata.saved_timestamp,
  to_timestamp((NULLIF(doc->>'reported_date'::text, ''::text)::bigint / 1000)::double precision) AS reported,
  doc->>'from' as from_phone,
  
  
  -- Robust message extraction handling all possible JSON structures
  COALESCE(
    -- Handle object format: doc.sms_message.message.value
    CASE WHEN jsonb_typeof(doc->'sms_message'->'message') = 'object'
         THEN doc->'sms_message'->'message'->>'value' END,
    -- Handle string format: doc.sms_message.message
    doc->'sms_message'->>'message',
    -- Fallback to parsed fields
    doc->'fields'->>'message',
    doc->'fields'->>'sms_message',
    -- Historical variants
    doc->>'sms_content',
    doc->>'content'
  ) as message_content,
  
  to_timestamp((NULLIF(doc->>'reported_date'::text, ''::text)::bigint / 1000)::double precision) as message_timestamp,
  
  to_timestamp((NULLIF(doc->>'reported_date'::text, ''::text)::bigint / 1000)::double precision) - 
  LAG(to_timestamp((NULLIF(doc->>'reported_date'::text, ''::text)::bigint / 1000)::double precision)) 
  OVER (PARTITION BY doc->>'from' ORDER BY to_timestamp((NULLIF(doc->>'reported_date'::text, ''::text)::bigint / 1000)::double precision)) as time_since_last_message,
  
  -- Basic health status
  CASE
    WHEN doc->>'errors' IS NOT NULL THEN 'processing_error'
    WHEN doc->>'_deleted' = 'true' THEN 'deleted'
    ELSE 'healthy'
  END as message_health

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
