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
  (couchdb.doc->>'age_years')::int as age,
  (couchdb.doc->>'is_minor')::boolean as is_minor,
  couchdb.doc->>'vmmc_no' as vmmc_no,
  couchdb.doc->'enrollment_facility'->>'name' as enrollment_facility,
  couchdb.doc->>'enrollment_location' as enrollment_location
  (couchdb.doc->>'date_of_birth')::date as date_of_birth,
  couchdb.doc->>'sex' as sex
FROM {{ ref("contact") }} contact
INNER JOIN {{ source('couchdb', env_var('POSTGRES_TABLE')) }} couchdb ON couchdb._id = uuid
WHERE contact.contact_type = 'person'
{% if is_incremental() %}
  AND contact.saved_timestamp >= {{ max_existing_timestamp('saved_timestamp') }}
{% endif %}
