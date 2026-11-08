class ConfigureParkcrestEmailWaitlist < ActiveRecord::Migration[8.1]
  DESTINATION = "info@parkcrestchildcaresociety.ca"

  def up
    execute <<~SQL.squish
      UPDATE daycares
      SET application_email = #{connection.quote(DESTINATION)},
          application_type = 'email_only',
          support_status = 'enabled',
          integration_settings = #{connection.quote({ provider_key: "parkcrest", workflow_key: "school_age_waitlist_email", destination: DESTINATION }.to_json)}::jsonb,
          integration_version = 1,
          mapping_failure_reason = NULL,
          updated_at = CURRENT_TIMESTAMP
      WHERE source_facility_id = '335'
        AND city = 'Burnaby'
        AND postal_code = 'V5B 2L2'
    SQL
  end

  def down
    execute <<~SQL.squish
      UPDATE daycares
      SET application_type = 'external', support_status = 'unconfigured',
          integration_settings = '{}'::jsonb, integration_version = NULL,
          updated_at = CURRENT_TIMESTAMP
      WHERE integration_settings->>'provider_key' = 'parkcrest'
    SQL
  end
end
