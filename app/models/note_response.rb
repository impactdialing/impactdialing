class NoteResponse < ActiveRecord::Base
  belongs_to :voter
  belongs_to :note
end