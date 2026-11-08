require "open3"

namespace :ymca do
  desc "Run the real YMCA workflow in experiment mode and stop at final review"
  task experiment: :environment do
    child_id = Integer(ENV.fetch("CHILD_ID"))
    child = Child.includes(:general_application, user: :provider_connections).find(child_id)
    application = child.general_application || raise("Child #{child_id} has no general application")
    raise("General application is incomplete") unless application.valid?
    connection = child.user.provider_connections.find_by!(provider_key: "ymca")

    config = YAML.safe_load_file(
      Rails.root.join("config/integrations/ymca_child_care_waitlist.yml"),
      aliases: false
    ).deep_stringify_keys
    live = config.fetch("live_validation")
    scope = {
      provider_key: config.fetch("provider_key"),
      workflow_key: config.fetch("workflow_key"),
      external_location_id: live.dig("location", "id"),
      external_program_id: live.dig("program", "id")
    }
    current_mappings = IntegrationMappingVersion.current.where(**scope).index_by(&:step_key).transform_values do |version|
      {
        inventory_fingerprint: version.inventory_fingerprint,
        inventory: version.inventory,
        mapping: version.mapping,
        defaults: version.defaults
      }
    end

    request = {
      credential: { username: connection.username, password: connection.decrypted_password },
      snapshot: application.normalized_answers,
      program_text: "Infant Toddler",
      target: {
        external_location_id: scope.fetch(:external_location_id),
        external_program_id: scope.fetch(:external_program_id)
      },
      headless: ENV.fetch("HEADLESS", "true") != "false",
      debug_screenshot: ENV["YMCA_DEBUG_SCREENSHOT"],
      diagnostic: ENV["YMCA_DIAGNOSTIC"],
      current_mappings: current_mappings,
      canonical_catalog: application.normalized_answers.keys + %w[daycare.external_location_id daycare.external_program_id],
      allowed_default_policy: Automation::Ymca::ChildCareWaitlistAdapter::DEFAULT_POLICY
    }

    python = ENV.fetch("PYTHON", "python3")
    script = Rails.root.join("automation/run_ymca_experiment.py").to_s
    stdout, stderr, status = Open3.capture3(python, script, stdin_data: JSON.generate(request))
    request = nil
    raise("YMCA worker failed to start") unless status.success?
    result = JSON.parse(stdout)

    result.fetch("mapping_changes", []).each do |change|
      Integrations::MappingStore.new.call(
        scope: scope.merge(step_key: change.fetch("step")),
        inventory: change.fetch("inventory"),
        mapping: change.fetch("mapping"),
        defaults: change.fetch("defaults"),
        warnings: change.fetch("warnings")
      )
    end

    safe_result = result.slice(
      "status", "reached_review", "child_profile_action", "target", "error_type", "error_stage", "error_detail",
      "error_location", "error_controls", "diagnostic_data"
    )
    puts JSON.pretty_generate(safe_result)
    raise("YMCA experiment did not reach review (#{result["error_type"] || "unknown error"})") unless result["reached_review"]
  ensure
    request = nil
    stdout = nil
    stderr = nil
  end
end
