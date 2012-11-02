class AddProviderToCallAttemptAndSession < ActiveRecord::Migration
  def change
    add_column :call_attempts, :service_provider, :string
    add_column :caller_sessions, :service_provider, :string
  end
end
