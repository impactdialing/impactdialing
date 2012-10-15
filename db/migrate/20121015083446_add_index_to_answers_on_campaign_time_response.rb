class AddIndexToAnswersOnCampaignTimeResponse < ActiveRecord::Migration
  def up
    add_index :answers, [:campaign_id, :created_at, :possible_response_id], name: 'index_answers_on_campaign_created_at_possible_response'
    remove_index :index_answers_count_question
  end

  def down
    remove_index :index_answers_on_campaign_created_at_possible_response
    add_index "answers", ["question_id", "campaign_id", "created_at"], :name => "index_answers_count_question"
  end
end
