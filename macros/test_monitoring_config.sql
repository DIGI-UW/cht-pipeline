{% macro test_monitoring_config() %}
  {% do log("=== MONITORING CONFIGURATION TEST ===", info=true) %}
  {% do log("MONITORING_PHONE_DIGICEL: " ~ env_var("MONITORING_PHONE_DIGICEL", "NOT_SET"), info=true) %}
  {% do log("MONITORING_PHONE_FLOW: " ~ env_var("MONITORING_PHONE_FLOW", "NOT_SET"), info=true) %}
  {% do log("POSTGRES_TABLE: " ~ env_var("POSTGRES_TABLE", "NOT_SET"), info=true) %}
  {% do log("POSTGRES_SCHEMA: " ~ env_var("POSTGRES_SCHEMA", "NOT_SET"), info=true) %}
  
  {% set digicel_phone = env_var("MONITORING_PHONE_DIGICEL", "") %}
  {% set flow_phone = env_var("MONITORING_PHONE_FLOW", "") %}
  
  {% if digicel_phone == "" %}
    {% do log("WARNING: MONITORING_PHONE_DIGICEL is not set!", info=true) %}
  {% endif %}
  
  {% if flow_phone == "" %}
    {% do log("WARNING: MONITORING_PHONE_FLOW is not set!", info=true) %}
  {% endif %}
  
  {% do log("=====================================", info=true) %}
{% endmacro %}
