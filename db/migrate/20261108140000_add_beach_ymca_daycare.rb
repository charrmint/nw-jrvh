class AddBeachYmcaDaycare < ActiveRecord::Migration[8.1]
  SOURCE_FACILITY_ID = "ymca_bc:a3lJQ000001BjHPYA0"

  def up
    daycare = Class.new(ActiveRecord::Base) do
      self.table_name = "daycares"
    end

    record = daycare.find_or_initialize_by(source_facility_id: SOURCE_FACILITY_ID)
    record.assign_attributes(
      name: "Beach YMCA",
      address: "1475 Burrard St",
      city: "Vancouver",
      postal_code: "V6Z 3B5",
      website_url: "https://mycommunity.bc.ymca.ca/s/find-child-care",
      application_url: "https://mycommunity.bc.ymca.ca/s/find-child-care",
      care_types: [ { "key" => "infant_toddler", "label" => "Infant Toddler" } ],
      services: {},
      reported_vacancies: {},
      application_type: "authenticated_portal",
      support_status: "enabled",
      integration_settings: {
        "provider_key" => "ymca_bc",
        "workflow_key" => "child_care_waitlist",
        "external_location_id" => "a3lJQ000001BjHPYA0",
        "external_program_id" => "a3CJQ00000OFo8L2AT",
        "centre_name" => "Beach YMCA",
        "program_name" => "Beach YMCA Infant Toddler",
        "program_text" => "Infant Toddler"
      },
      integration_version: 1,
      mapping_updated_at: Time.current,
      mapping_failure_reason: nil
    )
    record.save!
  end

  def down
    execute "DELETE FROM daycares WHERE source_facility_id = #{connection.quote(SOURCE_FACILITY_ID)}"
  end
end
