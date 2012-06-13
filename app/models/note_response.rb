class NoteResponse < ActiveRecord::Base
  belongs_to :voter
  belongs_to :note
  belongs_to :call_attempt
  belongs_to :campaign

  scope :for, lambda{|note| where(["note_id = ?",note.id])}
  scope :for_notes, lambda{|note_ids| where("note_id in (?) ", note_ids)}
  
  def self.note_ids(campaign_id)
    NoteResponse.all(:select=>"distinct note_id", :conditions=>"campaign_id = #{campaign_id}", :order => "note_id").collect{|nr| nr.note_id }    
  end
  
  def self.response_texts(note_ids, note_responses)
    texts = []
    note_ids.each_with_index do |note_id, index|
      unless note_responses.collect{|x| x.note_id}.include?(note_id)
        texts << ""
      else
        texts << note_responses.detect{|at| at.note_id == note_id}.response
      end
    end
    texts
  end
end