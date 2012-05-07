class AddCallAttemptIdToNoteResponses < ActiveRecord::Migration
  def self.up
    add_column(:note_responses, :call_attempt_id, :integer)
  end

  def self.down
    remove_column(:note_responses, :call_attempt_id)
  end
end
