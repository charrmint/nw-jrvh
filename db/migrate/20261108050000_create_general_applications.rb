class CreateGeneralApplications < ActiveRecord::Migration[8.1]
  def change
    create_table :general_applications do |t|
      t.references :user, null: false, foreign_key: true
      t.references :child, null: false, foreign_key: true
      t.jsonb :answers, null: false, default: {}
      t.timestamps
    end

    add_index :general_applications, [ :user_id, :child_id ], unique: true
  end
end
