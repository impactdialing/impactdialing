class AddIndexToAnswers < ActiveRecord::Migration
  def change
    add_index :answers, [:campaign_id, :caller_id], :name => "index_answers_campaign_id_caller_id"
  end
end
