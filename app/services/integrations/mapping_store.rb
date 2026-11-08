module Integrations
  class MappingStore
    def call(scope:, inventory:, mapping:, defaults:, warnings: [])
      observed = Automation::FieldInventory.new(inventory)
      relation = IntegrationMappingVersion.for_scope(**scope)
      current = relation.current.first
      return current if current&.inventory_fingerprint == observed.fingerprint

      IntegrationMappingVersion.transaction do
        relation.lock.where(current: true).update_all(current: false, updated_at: Time.current)
        relation.create!(
          version: relation.maximum(:version).to_i + 1,
          inventory_fingerprint: observed.fingerprint,
          inventory: observed.document,
          mapping: mapping,
          defaults: defaults,
          validation_warnings: warnings,
          current: true
        )
      end
    end
  end
end
