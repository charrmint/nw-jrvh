class CreateIntegrationMappingVersions < ActiveRecord::Migration[8.1]
  def change
    create_table :integration_mapping_versions do |t|
      t.string :provider_key, null: false
      t.string :workflow_key, null: false
      t.string :step_key, null: false
      t.string :external_location_id
      t.string :external_program_id
      t.integer :version, null: false
      t.string :inventory_fingerprint, null: false
      t.jsonb :inventory, null: false, default: {}
      t.jsonb :mapping, null: false, default: {}
      t.jsonb :defaults, null: false, default: {}
      t.jsonb :validation_warnings, null: false, default: []
      t.boolean :current, null: false, default: true
      t.timestamps
    end

    add_index :integration_mapping_versions,
      %i[provider_key workflow_key step_key external_location_id external_program_id version],
      unique: true,
      nulls_not_distinct: true,
      name: "index_integration_mapping_versions_on_scope_and_version"
    add_index :integration_mapping_versions,
      %i[provider_key workflow_key step_key external_location_id external_program_id],
      unique: true,
      nulls_not_distinct: true,
      where: "current",
      name: "index_current_integration_mapping_versions_on_scope"
  end
end
