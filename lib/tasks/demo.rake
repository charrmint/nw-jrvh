# Configures the three demo providers on ANY database (Beach YMCA, Beyond Care, Parkcrest).
# It mirrors the end state of the provider migrations, but finds daycares by their official
# facility id instead of a hard-coded row id, so it also works on a fresh database.
#
#   ruby bin/rails demo:setup_providers
#
# On an empty database import the two BC daycares first:
#   PowerShell:  $env:BC_DAYCARE_FACILITY_IDS="415,335"; ruby bin/rails daycares:import_bc
namespace :demo do
  desc "Configure Beach YMCA, Beyond Care and Parkcrest for the demo (safe to run repeatedly)"
  task setup_providers: :environment do
    # --- Beach YMCA (created if missing) ---------------------------------------------------
    ymca = Daycare.find_or_initialize_by(source_facility_id: "ymca_bc:a3lJQ000001BjHPYA0")
    ymca.assign_attributes(
      name: "Beach YMCA", address: "1475 Burrard St", city: "Vancouver", postal_code: "V6Z 3B5",
      website_url: "https://mycommunity.bc.ymca.ca/s/find-child-care",
      application_url: "https://mycommunity.bc.ymca.ca/s/find-child-care",
      care_types: [ { "key" => "infant_toddler", "label" => "Infant Toddler" } ],
      application_type: "authenticated_portal", support_status: "enabled",
      integration_settings: {
        "provider_key" => "ymca_bc", "workflow_key" => "child_care_waitlist",
        "external_location_id" => "a3lJQ000001BjHPYA0", "external_program_id" => "a3CJQ00000OFo8L2AT",
        "centre_name" => "Beach YMCA", "program_name" => "Beach YMCA Infant Toddler", "program_text" => "Infant Toddler"
      },
      integration_version: ymca.integration_version || 1,
      mapping_updated_at: ymca.mapping_updated_at || Time.current, mapping_failure_reason: nil
    )
    ymca.save!
    puts "Beach YMCA: ready (id #{ymca.id})"

    # --- Beyond Care (BC facility 415) -----------------------------------------------------
    beyond = Daycare.find_by(source_facility_id: "415")
    abort "Beyond Care (BC facility 415) is not in this database. Import it first: BC_DAYCARE_FACILITY_IDS=415,335 ruby bin/rails daycares:import_bc" unless beyond
    beyond.update!(
      application_url: "https://bcchildcentre.ca/wait-list", application_type: "public_form", support_status: "enabled",
      integration_settings: {
        "provider_key" => "beyond_care", "workflow_key" => "public_waitlist", "external_location_id" => "415",
        "form_path" => "/wait-list", "submission_path" => "/api/forms/waitlist", "submit_enabled" => true
      },
      integration_version: [ beyond.integration_version.to_i, 2 ].max, mapping_failure_reason: nil
    )
    puts "Beyond Care: ready (id #{beyond.id}, #{beyond.name})"

    # --- Parkcrest (BC facility 335, Burnaby V5B 2L2) -------------------------------------
    destination = "info@parkcrestchildcaresociety.ca"
    parkcrest = Daycare.find_by(source_facility_id: "335", city: "Burnaby", postal_code: "V5B 2L2")
    abort "Parkcrest (BC facility 335) is not in this database. Import it first: BC_DAYCARE_FACILITY_IDS=415,335 ruby bin/rails daycares:import_bc" unless parkcrest
    parkcrest.update!(
      application_email: destination, website_url: "https://www.parkcrestchildcaresociety.ca/", phone: "604-294-6224",
      services: parkcrest.services.merge("contact_email" => destination),
      application_type: "email_only", support_status: "enabled",
      integration_settings: { "provider_key" => "parkcrest", "workflow_key" => "school_age_waitlist_email", "destination" => destination },
      integration_version: parkcrest.integration_version || 1, mapping_failure_reason: nil
    )
    puts "Parkcrest: ready (id #{parkcrest.id}, #{parkcrest.name})"

    # --- reviewed YMCA form mapping (avoids needing Databricks for the first YMCA run) -----
    Rake::Task["integrations:import_ymca_live_observation"].invoke
    puts "YMCA field mapping: imported"
  end
end
