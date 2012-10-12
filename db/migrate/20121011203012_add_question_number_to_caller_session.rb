class AddQuestionNumberToCallerSession < ActiveRecord::Migration
  def change
    add_column :caller_sessions, :question_number, :integer
  end
end
