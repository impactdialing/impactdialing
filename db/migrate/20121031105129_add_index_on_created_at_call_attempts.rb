class AddIndexOnCreatedAtCallAttempts < ActiveRecord::Migration
  def up
    add_index :call_attempts, :created_at
  end

  def down
    remove_index :call_attempts, :column => :created_at
  end
end
