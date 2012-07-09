class AddCallerPasswordToAccount < ActiveRecord::Migration
  def self.up
    add_column(:accounts, :caller_password, :text)
    add_column(:accounts, :caller_hashed_password_salt, :text)
  end

  def self.down
    remove_column(:accounts, :caller_password)
    remove_column(:accounts, :caller_hashed_password_salt)    
  end
end
