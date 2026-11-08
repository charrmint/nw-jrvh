require "open3"

module Automation
  module BeyondCare
    class ExperimentRunner
      class Error < StandardError
        attr_reader :result

        def initialize(message, result: {})
          super(message)
          @result = result
        end
      end

      def initialize(child:, daycare:, headless: true, debug_screenshot: nil, snapshot: nil, submit: false)
        @child = child
        @daycare = daycare
        @headless = headless
        @debug_screenshot = debug_screenshot
        @snapshot = snapshot
        @submit = submit
      end

      def call
        application = @child.general_application || raise(Error, "This child has no central application")
        raise Error, "The central application is incomplete" unless application.valid?

        settings = @daycare.beyond_care_integration_settings
        raise Error, "This daycare is not configured for Beyond Care automation" unless settings

        config = YAML.safe_load_file(
          Rails.root.join("config/integrations/beyond_care_waitlist.yml"),
          aliases: false
        ).deep_stringify_keys
        if @submit && (config["live_submit_enabled"] != true || settings["submit_enabled"] != true || @daycare.support_status != "enabled")
          raise Error, "Beyond Care live submission is disabled"
        end
        scope = {
          provider_key: config.fetch("provider_key"),
          workflow_key: config.fetch("workflow_key"),
          external_location_id: settings.fetch("external_location_id"),
          external_program_id: nil
        }

        request = build_request(application:, scope:)
        stdout, _stderr, status = Open3.capture3(
          ENV.fetch("PYTHON", "python3"),
          Rails.root.join("automation/run_beyond_care_experiment.py").to_s,
          stdin_data: JSON.generate(request)
        )
        request = nil
        raise Error, "The Beyond Care browser worker could not start" unless status.success?

        result = JSON.parse(stdout)
        store_mapping_changes(result, scope)
        safe_result(result)
      rescue JSON::ParserError
        raise Error, "The Beyond Care browser worker returned an invalid result"
      ensure
        request = nil
        stdout = nil
      end

      private
        def build_request(application:, scope:)
          current_mappings = IntegrationMappingVersion.current.where(**scope).index_by(&:step_key).transform_values do |version|
            {
              inventory_fingerprint: version.inventory_fingerprint,
              inventory: version.inventory,
              mapping: version.mapping,
              defaults: version.defaults
            }
          end

          {
            snapshot: @snapshot || application.normalized_answers,
            submit_enabled: @submit,
            headless: @headless,
            debug_screenshot: @debug_screenshot,
            current_mappings: current_mappings,
            canonical_catalog: application.normalized_answers.keys,
            allowed_default_policy: WaitlistAdapter::DEFAULT_POLICY
          }.compact
        end

        def store_mapping_changes(result, scope)
          result.fetch("mapping_changes", []).each do |change|
            Integrations::MappingStore.new.call(
              scope: scope.merge(step_key: change.fetch("step")),
              inventory: change.fetch("inventory"),
              mapping: change.fetch("mapping"),
              defaults: change.fetch("defaults"),
              warnings: change.fetch("warnings")
            )
          end
          return if result.fetch("mapping_changes", []).empty?

          @daycare.update!(mapping_updated_at: Time.current, mapping_failure_reason: nil)
        end

        def safe_result(result)
          result.slice(
            "status", "reached_submit_ready", "submitted", "submission_confirmed", "submission_attempted",
            "blocker", "blocker_detail", "filled_fields", "observed_field_keys",
            "mapping_reused", "persistence", "pre_submit_form_write_requests",
            "background_write_request_count",
            "error_type", "error_stage", "error_detail"
          )
        end
    end
  end
end
