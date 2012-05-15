class NoteResponse < ActiveRecord::Base
  belongs_to :voter
  belongs_to :note
  belongs_to :call_attempt
  belongs_to :campaign

  scope :for, lambda{|note| where(["note_id = ?",note.id])}
  scope :for_notes, lambda{|note_ids| where("note_id in (?) ", note_ids)}
end