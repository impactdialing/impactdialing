class AddHouseholdIdToVoters < ActiveRecord::Migration
  def up
    add_column :voters, :household_id, :integer
    add_index :voters, :household_id

    execute <<-SQL
      ALTER TABLE voters ADD CONSTRAINT fk_voters_households
      FOREIGN KEY (household_id)
      REFERENCES households(id)
    SQL
  end

  def down
    execute <<-SQL
      ALTER TABLE voters DROP FOREIGN KEY fk_voters_households
    SQL
    remove_index :voters, :household_id
    remove_column :voters, :household_id
  end
end
