namespace :integrations do
  desc "Import the reviewed YMCA live observation as current mapping versions"
  task import_ymca_live_observation: :environment do
    path = Rails.root.join("config/integrations/ymca_child_care_waitlist_observation.yml")
    document = YAML.safe_load_file(path, aliases: false).deep_symbolize_keys
    base_scope = document.fetch(:scope)

    document.fetch(:steps).each do |step_key, step|
      scope = base_scope.merge(step_key: step_key.to_s)
      inventory = Automation::FieldInventory.new(step.fetch(:inventory))
      relation = IntegrationMappingVersion.for_scope(**scope)
      current = relation.current.first
      next if current&.inventory_fingerprint == inventory.fingerprint

      IntegrationMappingVersion.transaction do
        relation.lock.where(current: true).update_all(current: false, updated_at: Time.current)
        relation.create!(
          version: relation.maximum(:version).to_i + 1,
          inventory_fingerprint: inventory.fingerprint,
          inventory: inventory.document,
          mapping: step.fetch(:mapping),
          defaults: step.fetch(:defaults),
          validation_warnings: step.fetch(:warnings),
          current: true
        )
      end
    end
  end
end
