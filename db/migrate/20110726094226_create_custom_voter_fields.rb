class CreateCustomVoterFields < ActiveRecord::Migration
  def self.up
    create_table :custom_voter_fields do |t|
      t.column :name, :string, :null => false
    end
  end

  def self.down
    drop_table :custom_voter_fields
  end
end
