class AddIndexForGroupByStatusEnabledVoters < ActiveRecord::Migration
  def self.up
    add_index(:answers, [:question_id, :campaign_id], :name => 'index_answers_distinct_question')    
    #add_index(:answers, [:possible_response_id, :campaign_id, :caller_id, :created_at], :name => 'index_answers_count_possible_response')    
  end

  def self.down
  end
end

