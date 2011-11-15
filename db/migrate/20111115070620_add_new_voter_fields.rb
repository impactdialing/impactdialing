class AddNewVoterFields < ActiveRecord::Migration
  def self.up
    add_column :voters, :address, :string
    add_column :voters, :city, :string
    add_column :voters, :state, :string
    add_column :voters, :zip_code, :string
    add_column :voters, :country, :string    
    remove_column :voters, :Age
    remove_column :voters, :Gender
  end

  def self.down
    remove_column :voters, :address
    remove_column :voters, :city
    remove_column :voters, :state
    remove_column :voters, :zip_code
    remove_column :voters, :country            
    add_column :voters, :Gender, :string
    add_column :voters, :Age, :string
    
  end
end

