class RemoveDuplicateIndexOnAnswers < ActiveRecord::Migration
  def up
    remove_index :answers, name: 'index_answers_count_question_id'
  end

  def down
    add_index(:answers, [:possible_response_id,:campaign_id,:caller_id, :created_at], :name => 'index_answers_count_question_id')
  end
end
