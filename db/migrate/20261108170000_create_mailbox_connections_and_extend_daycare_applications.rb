class CreateMailboxConnectionsAndExtendDaycareApplications < ActiveRecord::Migration[8.1]
  def change
    create_table :mailbox_connections do |t|
      t.references :user, null: false, foreign_key: true, index: { unique: true }
      t.text :encrypted_access_token, null: false
      t.text :encrypted_refresh_token, null: false
      t.datetime :access_token_expires_at, null: false
      t.string :scope, null: false
      t.datetime :connected_at, null: false
      t.timestamps
    end

    change_column_null :daycare_applications, :submitted_at, true
    add_column :daycare_applications, :apply_request_id, :string
    add_column :daycare_applications, :prepared_content, :jsonb, null: false, default: {}
    add_column :daycare_applications, :sent_at, :datetime
    add_column :daycare_applications, :last_error, :string
    add_index :daycare_applications, :apply_request_id, unique: true
  end
end
