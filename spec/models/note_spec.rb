require 'spec_helper'

describe Note do

  context 'validations' do
    it {should validate_presence_of :note}
    it {should validate_presence_of :script}
    it {should validate_presence_of :script_order}
    it {should validate_numericality_of :script_order}
  end

  describe "note texts" do
    let(:script) { Factory(:script) }
    let(:campaign) { Factory(:campaign, :script => script) }
    let(:voter) { Factory(:voter, :campaign => campaign) }

    it "should return the text of all notes not deleted" do
      note1 = Factory(:note, note: "note1", script: script)
      note2 = Factory(:note, note: "note2", script: script)
      Note.note_texts([note1.id, note2.id]).should eq(["note1", "note2"])
    end

    it "should return the text of all notes not deleted in correct order" do
      note1 = Factory(:note, note: "note1", script: script)
      note2 = Factory(:note, note: "note2", script: script)
      Note.note_texts([note2.id, note1.id]).should eq(["note2", "note1"])
    end

    it "should return the blank text for notes that dont exist" do
      note1 = Factory(:note, note: "note1", script: script)
      note2 = Factory(:note, note: "note2", script: script)
      Note.note_texts([note2.id, 13212, note1.id]).should eq(["note2","", "note1"])
    end


  end

end
