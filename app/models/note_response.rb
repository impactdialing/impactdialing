class NoteResponse < ActiveRecord::Base
  belongs_to :voter
  belongs_to :note

  scope :for, lambda{|note| where(["note_id = ?",note.id])}
end