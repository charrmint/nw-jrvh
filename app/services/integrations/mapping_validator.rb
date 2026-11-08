require "set"

module Integrations
  class MappingValidator
    Result = Data.define(:mapping, :defaults, :warnings)

    def initialize(inventory:, canonical_catalog:, allowed_default_policy: {})
      @inventory = inventory.deep_stringify_keys
      @canonical_catalog = canonical_catalog.map(&:to_s).to_set
      @allowed_default_policy = allowed_default_policy.deep_stringify_keys
    end

    def call(proposal)
      proposal = proposal.deep_stringify_keys
      fields = Array(@inventory["fields"]).index_by { |field| field.fetch("key") }
      warnings = []

      mapping = proposal.fetch("mappings", {}).each_with_object({}) do |(live_key, canonical_key), accepted|
        unless live_key.is_a?(String) && canonical_key.is_a?(String)
          warnings << "Discarded non-string mapping"
          next
        end
        if @canonical_catalog.include?(live_key) && fields.key?(canonical_key)
          live_key, canonical_key = canonical_key, live_key
        end
        if live_key.start_with?("priority.") && %w[priority.affiliations priority.categories].include?(canonical_key)
          warnings << "Discarded branded priority mapping for #{live_key}"
          next
        end
        if live_key == "parent.marketing_sms"
          warnings << "Discarded marketing SMS mapping"
          next
        end
        unless fields.key?(live_key)
          warnings << "Discarded mapping for unobserved field #{live_key}"
          next
        end
        unless @canonical_catalog.include?(canonical_key)
          warnings << "Discarded mapping to unknown catalog key #{canonical_key}"
          next
        end
        accepted[live_key] = canonical_key
      end

      aliases = {
        "child.birthdate_or_estimated" => "child.date_of_birth",
        "school.catchment.cascade_or_inman" => "school.catchment",
        "parent.birthdate" => "parent.date_of_birth",
        "parent.mobile_phone" => "parent.local_phone",
        "parent.second_guardian" => "parent.second_guardian_name",
        "program_type" => "daycare.external_program_id",
        "centres" => "daycare.external_location_id"
      }
      fields.each_key do |live_key|
        mapping[live_key] = live_key if @canonical_catalog.include?(live_key)
        mapping[live_key] = aliases[live_key] if aliases[live_key] && @canonical_catalog.include?(aliases[live_key])
      end

      defaults = proposal.fetch("defaults", {}).each_with_object({}) do |(live_key, value), accepted|
        field = fields[live_key]
        unless field
          if live_key == "provider_specific_priority" && @allowed_default_policy[live_key] == value
            fields.each do |key, candidate|
              defaults[key] = value if key.start_with?("priority.") && Array(candidate["choices"]).include?(value)
            end
            next
          end
          if live_key == "marketing_sms" && @allowed_default_policy[live_key] == value
            sms = fields["parent.marketing_sms"]
            defaults["parent.marketing_sms"] = value if sms && boolean_no?(sms, value)
            next
          end
          warnings << "Discarded default for unobserved field #{live_key}"
          next
        end

        choices = Array(field["choices"])
        allowed_kind = default_kind(live_key)
        unless @allowed_default_policy[allowed_kind] == value && (choices.include?(value) || boolean_no?(field, value))
          warnings << "Discarded disallowed default for #{live_key}"
          next
        end
        accepted[live_key] = value
      end

      if @allowed_default_policy["provider_specific_priority"] == "No"
        fields.each do |live_key, field|
          defaults[live_key] = "No" if live_key.start_with?("priority.") && Array(field["choices"]).include?("No")
        end
      end

      sms = fields["parent.marketing_sms"]
      if @allowed_default_policy["marketing_sms"] == "No" && sms && boolean_no?(sms, "No")
        defaults["parent.marketing_sms"] = "No"
      end

      Result.new(mapping:, defaults:, warnings:)
    end

    private
      def default_kind(live_key)
        live_key.include?("sms") ? "marketing_sms" : "provider_specific_priority"
      end

      def boolean_no?(field, value)
        field["type"] == "checkbox" && value == "No"
      end
  end
end
