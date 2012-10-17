class DeleteUnecessaryColumnsCalls < ActiveRecord::Migration
  def up
    remove_column :calls, :conference_name
    remove_column :calls, :account_sid
    remove_column :calls, :conference_history
    remove_column :calls, :to_zip
    remove_column :calls, :from_state
    remove_column :calls, :called
    remove_column :calls, :from_country
    remove_column :calls, :caller_country
    remove_column :calls, :called_zip
    remove_column :calls, :direction
    remove_column :calls, :from_city
    remove_column :calls, :called_country    
    remove_column :calls, :caller_state
    remove_column :calls, :called_state
    remove_column :calls, :from
    remove_column :calls, :caller_zip    
    remove_column :calls, :from_zip    
    remove_column :calls, :application_sid
    remove_column :calls, :to_city
    remove_column :calls, :to_state
    remove_column :calls, :to
    remove_column :calls, :to_country
    remove_column :calls, :caller_city
    remove_column :calls, :api_version
    remove_column :calls, :caller
    remove_column :calls, :called_city
    remove_column :calls, :waiting_at
    remove_column :calls, :ended_at
  end

  def down
  end
end
