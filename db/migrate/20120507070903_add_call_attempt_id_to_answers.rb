class AddCallAttemptIdToAnswers < ActiveRecord::Migration
  def self.up
    add_column(:answers, :call_attempt_id, :integer)    
  end

  def self.down
    remove_column(:answers, :call_attempt_id, :integer)
  end
end
