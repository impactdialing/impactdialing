class AccountAddCharifyCustomerId < ActiveRecord::Migration
  def self.up
    add_column :accounts, :chargify_customer_id, :integer
  end

  def self.down
    remove_column :accounts, :chargify_customer_id
  end
end