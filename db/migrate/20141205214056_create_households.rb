class CreateHouseholds < ActiveRecord::Migration
  def up
    create_table :households do |t|
      t.integer :account_id, null: false
      t.integer :campaign_id, null: false
      t.integer :voter_list_id
      t.integer :last_call_attempt_id
      
      t.string :phone, null: false
      t.integer :enabled, null: false, default: 0
      t.string :status, null: false, default: 'not called'
      t.datetime :presented_at

      t.timestamps
    end

    add_index :households, :account_id
    add_index :households, :campaign_id
    add_index :households, :voter_list_id
    add_index :households, :last_call_attempt_id
    add_index :households, :enabled
    add_index :households, :phone
    add_index :households, :status
    add_index :households, :presented_at

    execute <<-SQL
      ALTER TABLE households ADD CONSTRAINT fk_households_campaigns
        FOREIGN KEY (campaign_id)
        REFERENCES campaigns(id)
    SQL

    execute <<-SQL
      ALTER TABLE households ADD CONSTRAINT fk_households_accounts
        FOREIGN KEY (account_id)
        REFERENCES accounts(id)
    SQL

    execute <<-SQL
      ALTER TABLE households ADD CONSTRAINT fk_households_last_call_attempt
        FOREIGN KEY (last_call_attempt_id)
        REFERENCES call_attempts(id)
    SQL
  end

  def down
    execute <<-SQL
      ALTER TABLE households DROP FOREIGN KEY fk_households_campaigns
    SQL

    execute <<-SQL
      ALTER TABLE households DROP FOREIGN KEY fk_households_accounts
    SQL

    execute <<-SQL
      ALTER TABLE households DROP FOREIGN KEY fk_households_last_call_attempt
    SQL

    drop_table :households
  end
end
