require 'spec_helper'

describe Note, :type => :model do

  context 'validations' do
    it {is_expected.to validate_presence_of :note}
    it {is_expected.to validate_presence_of :script}
    it {is_expected.to validate_presence_of :script_order}
    it {is_expected.to validate_numericality_of :script_order}
  end

  describe "note texts" do
    let(:script) { create(:script) }
    let(:campaign) { create(:campaign, :script => script) }
    let(:voter) { create(:voter, :campaign => campaign) }

    it "should return the text of all notes not deleted" do
      note1 = create(:note, note: "note1", script: script)
      note2 = create(:note, note: "note2", script: script)
      expect(Note.note_texts([note1.id, note2.id])).to eq(["note1", "note2"])
    end

    it "should return the text of all notes not deleted in correct order" do
      note1 = create(:note, note: "note1", script: script)
      note2 = create(:note, note: "note2", script: script)
      expect(Note.note_texts([note2.id, note1.id])).to eq(["note2", "note1"])
    end

    it "should return the blank text for notes that dont exist" do
      note1 = create(:note, note: "note1", script: script)
      note2 = create(:note, note: "note2", script: script)
      expect(Note.note_texts([note2.id, 13212, note1.id])).to eq(["note2","", "note1"])
    end


  end

end

# ## Schema Information
#
# Table name: `notes`
#
# ### Columns
#
# Name                | Type               | Attributes
# ------------------- | ------------------ | ---------------------------
# **`id`**            | `integer`          | `not null, primary key`
# **`note`**          | `text`             | `default(""), not null`
# **`script_id`**     | `integer`          | `not null`
# **`script_order`**  | `integer`          |
#
