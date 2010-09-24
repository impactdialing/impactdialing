class CampaignAddPredectiveType < ActiveRecord::Migration
  def self.up
    add_column :campaigns, :predective_type, :string
    add_column :call_attempts, :answertime, :datetime
    add_column :caller_sessions, :attempt_in_progress, :integer
  end

  def self.down
    remove_column :caller_sessions, :attempt_in_progress
    remove_column :call_attempts, :answertime
    remove_column :campaigns, :predective_type
  end
end
