class RenameVoterColumnsForConsistency < ActiveRecord::Migration
  def up
  	rename_column :voters, :Phone, :phone
  	rename_column :voters, :CustomID, :custom_id
  	rename_column :voters, :LastName, :last_name
  	rename_column :voters, :FirstName, :first_name
  	rename_column :voters, :MiddleName, :middle_name  	
  	rename_column :voters, :Suffix, :suffix
  	rename_column :voters, :Email, :email
  end

  def down
  	rename_column :voters, :phone, :Phone
  	rename_column :voters, :custom_id, :CustomID
  	rename_column :voters, :last_name, :LastName
  	rename_column :voters, :first_name, :FirstName
  	rename_column :voters, :middle_name, :MiddleName
  	rename_column :voters, :suffix, :Suffix
  	rename_column :voters, :email, :Email
  end
end
