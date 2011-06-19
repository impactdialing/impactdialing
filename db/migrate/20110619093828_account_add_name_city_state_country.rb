class AccountAddNameCityStateCountry < ActiveRecord::Migration
  def self.up
    add_column :accounts, :city, :string
    add_column :accounts, :state, :string
    add_column :accounts, :country, :string
    add_column :accounts, :name, :string
  end

  def self.down
    remove_column :accounts, :name
    remove_column :accounts, :country
    remove_column :accounts, :state
    remove_column :accounts, :city
  end
end