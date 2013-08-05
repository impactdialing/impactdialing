class CreateAccounts < ActiveRecord::Migration
  def self.up
    create_table :accounts do |t|
      t.boolean :paid
      t.column  :created_at , :timestamp, :null => true
      t.column  :updated_at , :timestamp, :null => true
    end
    add_column :users, :account_id, :integer
    execute 'insert into accounts (id, paid) select id, paid from users'
    remove_column :users, :paid
    execute 'update users set account_id = id'
    each_client_associated_table do |table|
      rename_column table, :user_id, :account_id
    end
  end

  def self.down
    each_client_associated_table do |table|
      rename_column table, :account_id, :user_id
    end
    add_column :users, :paid, :boolean
    execute 'update users inner join accounts on users.account_id = accounts.id set users.paid = 1 where accounts.paid = 1'
    remove_column :users, :account_id
    drop_table :accounts
  end

  def self.each_client_associated_table
    %w(campaigns recordings custom_voter_fields billing_accounts scripts callers voter_lists voters families).each do |table|
      yield table
    end
  end
end
