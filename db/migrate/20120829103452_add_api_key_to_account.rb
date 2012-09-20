class AddApiKeyToAccount < ActiveRecord::Migration
  def self.up
    add_column :accounts, :api_key, :string, :default => ""
  end

  def self.down
    remove_column :accounts, :api_key
  end
end
