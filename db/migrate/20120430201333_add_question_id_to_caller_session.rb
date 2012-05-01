class AddQuestionIdToCallerSession < ActiveRecord::Migration
  def self.up
    add_column(:caller_sessions, :question_id, :integer)
  end

  def self.down
    remove_column(:caller_sessions, :question_id)
  end
end
