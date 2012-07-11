class AddIndexIndexAnswersCountPossibleResponseCampaign < ActiveRecord::Migration
  def self.up
    add_index(:answers, [:possible_response_id,:campaign_id,:caller_id, :created_at], :name => 'index_answers_count_possible_response_campaign')    
  end

  def self.down
  end
end
