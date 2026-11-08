require "open3"

module Automation
  module Ymca
    class ExperimentRunner
      class Error < StandardError
        attr_reader :result

        def initialize(message, result: {})
          super(message)
          @result = result
        end
      end

      def initialize(child:, daycare:, headless: true, snapshot: nil, submit: false)
        @child = child
        @daycare = daycare
        @headless = headless
        @snapshot = snapshot
        @submit = submit
      end

      def call
        application = @child.general_application || raise(Error, "This child has no central application")
        raise Error, "The central application is incomplete" unless application.valid?

        settings = @daycare.ymca_integration_settings
        raise Error, "This daycare is not configured for YMCA automation" unless settings

        connection = @child.user.provider_connections.find_by!(provider_key: "ymca")
        config = YAML.safe_load_file(
          Rails.root.join("config/integrations/ymca_child_care_waitlist.yml"),
          aliases: false
        ).deep_stringify_keys
        raise Error, "YMCA live submission is disabled" if @submit && config["live_submit_enabled"] != true
        scope = {
          provider_key: config.fetch("provider_key"),
          workflow_key: config.fetch("workflow_key"),
          external_location_id: settings.fetch("external_location_id"),
          external_program_id: settings.fetch("external_program_id")
        }

        request = build_request(application:, connection:, config:, settings:, scope:)
        stdout, _stderr, status = Open3.capture3(
          ENV.fetch("PYTHON", "python3"),
          Rails.root.join("automation/run_ymca_experiment.py").to_s,
          stdin_data: JSON.generate(request)
        )
        request = nil
        raise Error, "The YMCA browser worker could not start" unless status.success?

        result = JSON.parse(stdout)
        store_mapping_changes(result, scope)
        unless result["reached_review"]
          raise Error.new("YMCA did not reach its Review screen", result: safe_result(result))
        end

        safe_result(result)
      rescue ActiveRecord::RecordNotFound
        raise Error, "Connect the YMCA account in Settings before applying"
      ensure
        request = nil
        stdout = nil
      end

      private
        def build_request(application:, connection:, config:, settings:, scope:)
          current_mappings = IntegrationMappingVersion.current.where(**scope).index_by(&:step_key).transform_values do |version|
            {
              inventory_fingerprint: version.inventory_fingerprint,
              inventory: version.inventory,
              mapping: version.mapping,
              defaults: version.defaults
            }
          end

          {
            credential: { username: connection.username, password: connection.decrypted_password },
            snapshot: @snapshot || application.normalized_answers,
            submit_enabled: @submit,
            program_text: settings.fetch("program_text"),
            centre_text: settings.fetch("centre_name"),
            target: {
              external_location_id: scope.fetch(:external_location_id),
              external_program_id: scope.fetch(:external_program_id)
            },
            headless: @headless,
            current_mappings: current_mappings,
            canonical_catalog: application.normalized_answers.keys +
              %w[daycare.external_location_id daycare.external_program_id],
            allowed_default_policy: Automation::Ymca::ChildCareWaitlistAdapter::DEFAULT_POLICY
          }
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
        end

        def safe_result(result)
          result.slice(
            "status", "reached_review", "submitted", "submission_confirmed",
            "submission_attempted", "child_profile_action", "target",
            "error_type", "error_stage", "error_detail"
          )
        end
    end
  end
end
