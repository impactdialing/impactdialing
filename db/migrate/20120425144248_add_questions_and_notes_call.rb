class AddQuestionsAndNotesCall < ActiveRecord::Migration
  def self.up
    remove_column(:caller_sessions, :questions)
    remove_column(:caller_sessions, :notes)
    add_column(:calls, :questions, :text)
    add_column(:calls, :notes, :text)
    
    
  end

  def self.down
    remove_column(:calls, :questions)
    remove_column(:calls, :notes)
    
  end
end
