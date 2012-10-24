class AddIndexToCallerIdentities < ActiveRecord::Migration
  def change
    add_index :caller_identities, :pin, name: :index_caller_identities_pin
  end
end
