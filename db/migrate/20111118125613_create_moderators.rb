class CreateModerators < ActiveRecord::Migration
  def self.up
    create_table :moderators do |t|
      t.integer :caller_session_id
      t.string :call_sid

      t.timestamps
    end
  end

  def self.down
    drop_table :moderators
  end
end
