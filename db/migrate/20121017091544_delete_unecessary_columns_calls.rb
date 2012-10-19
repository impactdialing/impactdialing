class DeleteUnecessaryColumnsCalls < ActiveRecord::Migration
  def up
    remove_column :calls, :conference_name unless column_exists? :calls, :conference_name
    remove_column :calls, :account_sid unless column_exists? :calls, :account_sid
    remove_column :calls, :conference_history unless column_exists? :calls, :conference_history
    remove_column :calls, :to_zip unless column_exists? :calls, :to_zip
    remove_column :calls, :from_state unless column_exists? :calls, :from_state
    remove_column :calls, :called unless column_exists? :calls, :called
    remove_column :calls, :from_country unless column_exists? :calls, :from_city
    remove_column :calls, :caller_country unless column_exists? :calls, :caller_country
    remove_column :calls, :called_zip unless column_exists? :calls, :called_zip
    remove_column :calls, :direction unless column_exists? :calls, :direction
    remove_column :calls, :from_city unless column_exists? :calls, :from_city
    remove_column :calls, :called_country unless column_exists? :calls, :called_country     
    remove_column :calls, :caller_state unless column_exists? :calls, :caller_state
    remove_column :calls, :called_state unless column_exists? :calls, :called_state
    remove_column :calls, :from unless column_exists? :calls, :from
    remove_column :calls, :caller_zip unless column_exists? :calls, :caller_zip    
    remove_column :calls, :from_zip    unless column_exists? :calls, :from_zip
    remove_column :calls, :application_sid unless column_exists? :calls, :application_sid
    remove_column :calls, :to_city unless column_exists? :calls, :to_city
    remove_column :calls, :to_state unless column_exists? :calls, :to_state
    remove_column :calls, :to unless column_exists? :calls, :to
    remove_column :calls, :to_country unless column_exists? :calls, :to_country
    remove_column :calls, :caller_city unless column_exists? :calls, :caller_city
    remove_column :calls, :api_version unless column_exists? :calls, :api_version
    remove_column :calls, :caller unless column_exists? :calls, :caller
    remove_column :calls, :called_city unless column_exists? :calls, :called_city
    remove_column :calls, :waiting_at unless column_exists? :calls, :waiting_at
    remove_column :calls, :ended_at unless column_exists? :calls, :ended_at
  end

  def down
  end
end
