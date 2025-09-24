{{ test_monitoring_config() }}

-- Simple test query to show what phone numbers would be processed
SELECT 
  '{{ env_var("MONITORING_PHONE_DIGICEL", "NOT_SET") }}' as configured_digicel_phone,
  '{{ env_var("MONITORING_PHONE_FLOW", "NOT_SET") }}' as configured_flow_phone,
  CURRENT_TIMESTAMP as test_run_at
