class DropQuestionOrderFromQuestions < ActiveRecord::Migration
  def change
    remove_column :questions, :question_order
  end
end
