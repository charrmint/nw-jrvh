class CreateDaycareApplications < ActiveRecord::Migration[8.1]
  def change
    create_table :daycare_applications do |t|
      t.references :child, null: false, foreign_key: true
      t.references :daycare, null: false, foreign_key: true
      t.string :status, null: false
      t.datetime :submitted_at, null: false
      t.string :provider_application_id

      t.timestamps
    end

    add_index :daycare_applications, %i[child_id daycare_id], unique: true
  end
end
