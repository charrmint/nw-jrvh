class CreateChildren < ActiveRecord::Migration[8.1]
  def change
    create_table :children do |t|
      t.references :user, null: false, foreign_key: true
      t.string :full_name, null: false
      t.date :date_of_birth, null: false

      t.timestamps
    end
  end
end
