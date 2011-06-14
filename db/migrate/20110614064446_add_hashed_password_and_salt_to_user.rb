class AddHashedPasswordAndSaltToUser < ActiveRecord::Migration
  def self.up
    add_column :users, :hashed_password, :string
    add_column :users, :salt, :string
    User.reset_column_information
    User.all.each do |user|
      user.new_password = user.password
      user.save!
    end
    remove_column :users, :password
    add_column :users, :password_reset_code, :string
  end

  def self.down
    remove_column :users, :password_reset_code
    add_column :users, :password, :string
    remove_column :users, :salt
    remove_column :users, :hashed_password
  end
end
