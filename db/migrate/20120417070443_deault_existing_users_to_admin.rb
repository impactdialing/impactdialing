class DeaultExistingUsersToAdmin < ActiveRecord::Migration
  def self.up
    User.connection.execute("update users set role = 'admin' ");
  end

  def self.down
    User.connection.execute("update users set role = null ");
  end
end
