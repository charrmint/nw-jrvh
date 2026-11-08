class CreateProviderConnections < ActiveRecord::Migration[8.1]
  def change
    create_table :provider_connections do |t|
      t.references :user, null: false, foreign_key: true
      t.string :provider_key, null: false
      t.string :username, null: false
      t.text :encrypted_password, null: false
      t.timestamps
    end

    add_index :provider_connections, [ :user_id, :provider_key ], unique: true
  end
end
