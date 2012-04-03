class CreateCallerIdentity < ActiveRecord::Migration
  def self.up
    create_table :caller_identities do |t|
      t.string :session_key
      t.integer :caller_session_id
      t.integer :caller_id
      t.string :pin
      t.timestamps
    end
    
  end

  def self.down
    drop_table :caller_identities
  end
end
