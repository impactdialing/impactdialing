class AccountAddAutorechargeFields < ActiveRecord::Migration
  def self.up
    add_column :accounts, :autorecharge_enabled, :boolean, :default=>false
    add_column :accounts, :autorecharge_trigger, :float
    add_column :accounts, :autorecharge_amount, :float
  end

  def self.down
    remove_column :accounts, :autorecharge_amount
    remove_column :accounts, :autorecharge_trigger
    remove_column :accounts, :autorecharge_enabled
  end
end