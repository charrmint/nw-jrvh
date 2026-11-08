class AddBirthdateOptionsToChildren < ActiveRecord::Migration[8.1]
  def change
    change_column_null :children, :date_of_birth, true
    add_column :children, :expected_due_date, :date
    add_column :children, :birthdate_unknown, :boolean, null: false, default: false
  end
end
