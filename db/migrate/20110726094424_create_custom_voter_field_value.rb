class CreateCustomVoterFieldValue < ActiveRecord::Migration
  def self.up
    create_table :custom_voter_field_values do |t|
      t.integer :voter_id
      t.integer :custom_voter_field_id
      t.string :value
    end
  end

  def self.down
    drop_table :custom_voter_field_values
  end
end
