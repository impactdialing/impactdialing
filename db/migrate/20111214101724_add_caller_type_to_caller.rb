class AddCallerTypeToCaller < ActiveRecord::Migration
  def self.up
    add_column(:callers, :is_phones_only, :boolean, :default => false)
  end

  def self.down
    remove_column(:callers, :is_phones_only)
  end
end
