class DeleteUnecessaryColumnsCalls < ActiveRecord::Migration
  def up
    remove_column :calls, :conference_name unless column_exists? :conference_name
    remove_column :calls, :account_sid unless column_exists? :account_sid
    remove_column :calls, :conference_history unless column_exists? :conference_history
    remove_column :calls, :to_zip unless column_exists? :to_zip
    remove_column :calls, :from_state unless column_exists? :from_state
    remove_column :calls, :called unless column_exists? :called
    remove_column :calls, :from_country unless column_exists? :from_city
    remove_column :calls, :caller_country unless column_exists? :caller_country
    remove_column :calls, :called_zip unless column_exists? :called_zip
    remove_column :calls, :direction unless column_exists? :direction
    remove_column :calls, :from_city unless column_exists? :from_city
    remove_column :calls, :called_country unless column_exists? :called_country     
    remove_column :calls, :caller_state unless column_exists? :caller_state
    remove_column :calls, :called_state unless column_exists? :called_state
    remove_column :calls, :from unless column_exists? :from
    remove_column :calls, :caller_zip unless column_exists? :caller_zip    
    remove_column :calls, :from_zip    unless column_exists? :from_zip
    remove_column :calls, :application_sid unless column_exists? :application_sid
    remove_column :calls, :to_city unless column_exists? :to_city
    remove_column :calls, :to_state unless column_exists? :to_state
    remove_column :calls, :to unless column_exists? :to
    remove_column :calls, :to_country unless column_exists? :to_country
    remove_column :calls, :caller_city unless column_exists? :caller_city
    remove_column :calls, :api_version unless column_exists? :api_version
    remove_column :calls, :caller unless column_exists? :caller
    remove_column :calls, :called_city unless column_exists? :called_city
    remove_column :calls, :waiting_at unless column_exists? :waiting_at
    remove_column :calls, :ended_at unless column_exists? :ended_at
  end

  def down
  end
end
