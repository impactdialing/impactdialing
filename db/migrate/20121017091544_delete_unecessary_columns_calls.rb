class DeleteUnecessaryColumnsCalls < ActiveRecord::Migration
  def up
    remove_column :calls, :conference_name if column_exists? :calls, :conference_name
    remove_column :calls, :account_sid if column_exists? :calls, :account_sid
    remove_column :calls, :conference_history if column_exists? :calls, :conference_history
    remove_column :calls, :to_zip if column_exists? :calls, :to_zip
    remove_column :calls, :from_state if column_exists? :calls, :from_state
    remove_column :calls, :called if column_exists? :calls, :called
    remove_column :calls, :from_country if column_exists? :calls, :from_city
    remove_column :calls, :caller_country if column_exists? :calls, :caller_country
    remove_column :calls, :called_zip if column_exists? :calls, :called_zip
    remove_column :calls, :direction if column_exists? :calls, :direction
    remove_column :calls, :from_city if column_exists? :calls, :from_city
    remove_column :calls, :called_country if column_exists? :calls, :called_country     
    remove_column :calls, :caller_state if column_exists? :calls, :caller_state
    remove_column :calls, :called_state if column_exists? :calls, :called_state
    remove_column :calls, :from if column_exists? :calls, :from
    remove_column :calls, :caller_zip if column_exists? :calls, :caller_zip    
    remove_column :calls, :from_zip    if column_exists? :calls, :from_zip
    remove_column :calls, :application_sid if column_exists? :calls, :application_sid
    remove_column :calls, :to_city if column_exists? :calls, :to_city
    remove_column :calls, :to_state if column_exists? :calls, :to_state
    remove_column :calls, :to if column_exists? :calls, :to
    remove_column :calls, :to_country if column_exists? :calls, :to_country
    remove_column :calls, :caller_city if column_exists? :calls, :caller_city
    remove_column :calls, :api_version if column_exists? :calls, :api_version
    remove_column :calls, :caller if column_exists? :calls, :caller
    remove_column :calls, :called_city if column_exists? :calls, :called_city
    remove_column :calls, :waiting_at if column_exists? :calls, :waiting_at
    remove_column :calls, :ended_at if column_exists? :calls, :ended_at
  end

  def down
  end
end
