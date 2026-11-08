class ConfigureBeyondCareWaitlist < ActiveRecord::Migration[8.1]
  DAYCARE_ID = 5406
  SOURCE_FACILITY_ID = "415"
  APPLICATION_URL = "https://bcchildcentre.ca/wait-list"

  def up
    daycare = Class.new(ActiveRecord::Base) do
      self.table_name = "daycares"
    end
    record = daycare.find_by(id: DAYCARE_ID, source_facility_id: SOURCE_FACILITY_ID)
    raise "Beyond Care daycare 5406 / facility 415 was not found" unless record

    record.update!(
      application_url: APPLICATION_URL,
      application_type: "public_form",
      support_status: "needs_validation",
      integration_settings: {
        "provider_key" => "beyond_care",
        "workflow_key" => "public_waitlist",
        "external_location_id" => SOURCE_FACILITY_ID,
        "form_path" => "/wait-list",
        "submission_path" => "/api/forms/waitlist",
        "submit_enabled" => false
      },
      integration_version: 1,
      mapping_failure_reason: nil
    )
  end

  def down
    daycare = Class.new(ActiveRecord::Base) do
      self.table_name = "daycares"
    end
    record = daycare.find_by(id: DAYCARE_ID, source_facility_id: SOURCE_FACILITY_ID)
    return unless record&.application_url == APPLICATION_URL

    record.update!(
      application_url: nil,
      application_type: "external",
      support_status: "unconfigured",
      integration_settings: {},
      integration_version: nil,
      mapping_updated_at: nil,
      mapping_failure_reason: nil
    )
  end
end
