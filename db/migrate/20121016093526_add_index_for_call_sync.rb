class AddIndexForCallSync < ActiveRecord::Migration
  def up
    add_index :call_attempts, [:status, :tPrice, :tStatus, :sid], :name => "index_sync_calls"
  end

  def down
  end
end
