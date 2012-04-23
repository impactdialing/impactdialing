class AddQuestionsAndNotesToCall < ActiveRecord::Migration
  def self.up
    add_column(:caller_sessions, :questions, :text)
    add_column(:caller_sessions, :notes, :text)
  end

  def self.down
    remove_column(:caller_sessions, :questions)
    remove_column(:caller_sessions, :notes)
  end
end
