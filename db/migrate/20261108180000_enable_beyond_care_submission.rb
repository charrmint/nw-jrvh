class EnableBeyondCareSubmission < ActiveRecord::Migration[8.1]
  def up
    daycare = Class.new(ActiveRecord::Base) { self.table_name = "daycares" }
    record = daycare.find_by!(id: 5406, source_facility_id: "415")
    settings = record.integration_settings.deep_stringify_keys
    raise "Beyond Care integration is not configured" unless settings["provider_key"] == "beyond_care"

    record.update!(
      support_status: "enabled",
      integration_settings: settings.merge("submit_enabled" => true),
      integration_version: record.integration_version.to_i + 1
    )
  end

  def down
    daycare = Class.new(ActiveRecord::Base) { self.table_name = "daycares" }
    record = daycare.find_by(id: 5406, source_facility_id: "415")
    return unless record

    settings = record.integration_settings.deep_stringify_keys
    record.update!(
      support_status: "needs_validation",
      integration_settings: settings.merge("submit_enabled" => false),
      integration_version: [record.integration_version.to_i - 1, 1].max
    )
  end
end
