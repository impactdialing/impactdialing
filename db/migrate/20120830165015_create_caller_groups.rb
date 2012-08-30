class CreateCallerGroups < ActiveRecord::Migration
  def self.up
    create_table :caller_groups do |t|
      t.string :name, null: false
      t.integer :campaign_id, null: false

      t.timestamps
    end
    add_column :callers, :caller_group_id, :integer

  end

  def self.down
    drop_table :caller_groups
    remove_column :callers, :caller_group_id
  end
end
