class AddLastCallAttemptIdToAnswers < ActiveRecord::Migration
  def self.up
    Answer.connection.execute("update answers set call_attempt_id = (select last_call_attempt_id from voters where answers.voter_id = voters.id)");
  end

  def self.down
  end
end
