{{
  config(
    materialized = 'incremental',
    unique_key='uuid',
    on_schema_change='append_new_columns',
    indexes=[
      {'columns': ['uuid'], 'type': 'hash'},
      {'columns': ['saved_timestamp'], 'type': 'btree'},
      {'columns': ['patient_id'], 'type': 'hash'},
    ]
  )
}}

SELECT
  uuid,
  person.saved_timestamp,
  person.reported,
  person.age,
  person.is_minor,
  person.vmmc_no,
  person.enrollment_facility,
  person.enrollment_location,
  location.implementing_partner,
  location.district,
  location.province,
  couchdb.doc->>'patient_id' as patient_id
FROM {{ ref('person') }} person
JOIN {{ source('couchdb', env_var('POSTGRES_TABLE')) }} couchdb ON couchdb._id = uuid
JOIN location location ON location.facility ILIKE person.enrollment_facility
WHERE couchdb.doc->>'patient_id' IS NOT NULL
{% if is_incremental() %}
  AND person.saved_timestamp >= {{ max_existing_timestamp('saved_timestamp') }}
{% endif %}
