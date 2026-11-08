module Integrations
  class MappingResolver
    Result = Data.define(:version, :changed)

    def initialize(suggester: MappingSuggester.new)
      @suggester = suggester
    end

    def call(scope:, inventory:, canonical_catalog:, allowed_default_policy: {})
      observed = Automation::FieldInventory.new(inventory)
      relation = IntegrationMappingVersion.for_scope(**scope)
      current = relation.current.first
      return Result.new(version: current, changed: false) if current&.inventory_fingerprint == observed.fingerprint

      proposal = @suggester.call(
        inventory: observed.document,
        canonical_catalog: canonical_catalog,
        previous_inventory: current&.inventory,
        allowed_default_policy: allowed_default_policy
      )
      validated = MappingValidator.new(
        inventory: observed.document,
        canonical_catalog: canonical_catalog,
        allowed_default_policy: allowed_default_policy
      ).call(proposal)

      version = IntegrationMappingVersion.transaction do
        relation.lock.where(current: true).update_all(current: false, updated_at: Time.current)
        relation.create!(
          version: relation.maximum(:version).to_i + 1,
          inventory_fingerprint: observed.fingerprint,
          inventory: observed.document,
          mapping: validated.mapping,
          defaults: validated.defaults,
          validation_warnings: validated.warnings,
          current: true
        )
      end
      Result.new(version:, changed: true)
    end
  end
end
