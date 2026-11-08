class AddNamePartsToChildren < ActiveRecord::Migration[8.1]
  def change
    add_column :children, :first_name, :string
    add_column :children, :last_name, :string
    add_column :children, :birthdate_estimated, :boolean, null: false, default: false
  end
end
