class AddDomainToAccount < ActiveRecord::Migration
  def self.up
    add_column :accounts, :domain, :string
    execute 'update accounts a, users u set a.domain = u.domain where a.id = u.account_id'
    remove_column :users, :domain
  end

  def self.down
    add_column :users, :domain, :string
    execute 'update users u, accounts a set u.domain = a.domain where a.id = u.account_id'
    remove_column :accounts, :domain
  end
end
