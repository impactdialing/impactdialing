class AddIndexForAnswers < ActiveRecord::Migration
  def self.up
    add_index(:answers, [:question_id,:campaign_id,:created_at], :name => 'index_answers_count_question')        
  end

  def self.down
  end
end
