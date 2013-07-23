class RenameEmailToUsernameCaller < ActiveRecord::Migration
  def up
    rename_column :callers, :email, :username
  end

  def down
    rename_column :callers, :username, :email
  end
end
