class CreateDaycares < ActiveRecord::Migration[8.1]
  def change
    create_table :daycares do |t|
      t.string :source_facility_id, null: false
      t.string :name, null: false
      t.string :address
      t.string :city, null: false
      t.string :postal_code, null: false
      t.decimal :latitude, precision: 10, scale: 7
      t.decimal :longitude, precision: 10, scale: 7
      t.string :website_url
      t.string :application_url
      t.string :application_email
      t.string :phone
      t.jsonb :care_types, null: false, default: []
      t.jsonb :services, null: false, default: {}
      t.jsonb :reported_vacancies, null: false, default: {}
      t.datetime :vacancy_updated_at
      t.string :application_type, null: false, default: "external"
      t.string :support_status, null: false, default: "unconfigured"
      t.jsonb :integration_settings, null: false, default: {}
      t.integer :integration_version
      t.datetime :mapping_updated_at
      t.text :mapping_failure_reason

      t.timestamps
    end

    add_index :daycares, :source_facility_id, unique: true
    add_index :daycares, :city
    add_index :daycares, :postal_code
    add_index :daycares, :application_type
    add_index :daycares, :support_status
  end
end
