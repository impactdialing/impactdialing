class VoterAddResultsetResults < ActiveRecord::Migration
  def self.up
    add_column :voters, :result_json, :text
    add_column :call_attempts, :result_json, :text
  end

  def self.down
    remove_column :call_attempts, :result_json
    remove_column :voters, :result_json
  end
end