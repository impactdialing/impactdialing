class AddHouseholdIdToCallAttempts < ActiveRecord::Migration
  def up
    add_column :call_attempts, :household_id, :integer
    add_index :call_attempts, :household_id

    execute <<-SQL
      ALTER TABLE call_attempts ADD CONSTRAINT fk_call_attempts_households
        FOREIGN KEY (household_id)
        REFERENCES households(id)
    SQL
  end

  def down
    execute <<-SQL
      ALTER TABLE call_attempts DROP FOREIGN KEY fk_call_attempts_households
    SQL

    remove_index :call_attempts, :household_id
    remove_column :call_attempts, :household_id
  end
end
