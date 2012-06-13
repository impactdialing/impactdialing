class Note < ActiveRecord::Base
  validates_presence_of :note
  belongs_to :script
  
  def self.note_texts(note_ids)
    texts = []
    notes = Note.select("id, note").where("id in (?)",note_ids).order('id')
    note_ids.each_with_index do |note_id, index|
      unless notes.collect{|x| x.id}.include?(note_id)
        texts << ""
      else
        texts << notes.detect{|at| at.id == note_id}.note
      end
    end
    texts
  end
end
