class AddDomainToUsers < ActiveRecord::Migration
  def self.up
    add_column :users, :domain, :string
  end

  def self.down
    remove_column :users, :domain
  end
end
