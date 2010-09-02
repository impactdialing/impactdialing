class VoterAddResultDate < ActiveRecord::Migration
  def self.up
    add_column :voters, :result_date, :datetime
  end

  def self.down
    remove_column :voters, :result_date
  end
end
