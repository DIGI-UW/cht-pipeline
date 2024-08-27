{{
  config(
    materialized = 'incremental',
    unique_key='uuid',
    on_schema_change='append_new_columns',
    indexes=[
      {'columns': ['uuid'], 'type': 'hash'},
      {'columns': ['saved_timestamp']},
    ]
  )
}}

SELECT
  contact.uuid,
  contact.saved_timestamp,
  contact.reported,
  (doc->>'age_years')::int as age,
  (doc->>'is_minor')::boolean as is_minor,
  doc->>'vmmc_no' as vmmc_no,
  doc->'enrollment_facility'->>'name' as enrollment_facility,
  doc->>'enrollment_location' as enrollment_location
FROM {{ ref("contact") }} contact
INNER JOIN {{ env_var('POSTGRES_SCHEMA') }}.{{ env_var('POSTGRES_TABLE') }} couchdb ON couchdb._id = uuid
WHERE contact.contact_type = 'person'
{% if is_incremental() %}
  AND contact.saved_timestamp >= {{ max_existing_timestamp('saved_timestamp') }}
{% endif %}
