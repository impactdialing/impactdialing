class NoteResponse < ActiveRecord::Base
  belongs_to :voter
  belongs_to :note
  belongs_to :call_attempt

  scope :for, lambda{|note| where(["note_id = ?",note.id])}
end