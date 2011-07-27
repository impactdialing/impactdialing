class EditCustomVoterFields < ActiveRecord::Migration
  def self.up
    change_column :custom_voter_fields, :name, :string
    add_column :custom_voter_fields, :user_id, :integer
  end

  def self.down
    change_column :custom_voter_fields, :name, :integer
    remove_column :custom_voter_fields, :user_id
  end
end
