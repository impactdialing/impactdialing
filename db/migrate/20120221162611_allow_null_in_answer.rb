class AllowNullInAnswer < ActiveRecord::Migration
  def self.up
    change_column(:answers, :caller_id, :integer, :null => true)
  end

  def self.down
    change_column(:answers, :caller_id, :integer, :null => false)
  end
end
