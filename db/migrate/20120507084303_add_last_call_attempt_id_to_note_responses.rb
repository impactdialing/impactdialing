class AddLastCallAttemptIdToNoteResponses < ActiveRecord::Migration
  def self.up
    NoteResponse.connection.execute("update note_responses set call_attempt_id = (select last_call_attempt_id from voters where note_responses.voter_id = voters.id)");
  end

  def self.down
  end
end
