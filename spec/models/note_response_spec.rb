require 'rails_helper'

describe NoteResponse, :type => :model do  
  let(:campaign){ create(:campaign) }
  let(:script){ create(:script) }
  let(:notes){ create_list(:note, 2, script: script) }
  let(:unique_note_ids) do
    notes.map(&:id).uniq
  end

  it "should return unique note ids for a campaign" do
    notes.each do |note|
      create_list(:note_response, 2, {
        campaign: campaign,
        note: note,
        voter: create(:voter)
      })
    end
    expect(NoteResponse.note_ids(campaign.id)).to eq(unique_note_ids)
  end
  
  it "should return response_texts for notes" do
    note_responses = []
    notes.each do |note|
      note_responses << create(:note_response, {
        campaign: campaign,
        note_id: note.id,
        voter: create(:voter),
        response: "Test#{note.id}"
      })
    end
    expect(NoteResponse.response_texts(unique_note_ids, note_responses)).to eq(note_responses.map(&:response))
  end
end

# ## Schema Information
#
# Table name: `note_responses`
#
# ### Columns
#
# Name                   | Type               | Attributes
# ---------------------- | ------------------ | ---------------------------
# **`id`**               | `integer`          | `not null, primary key`
# **`voter_id`**         | `integer`          | `not null`
# **`note_id`**          | `integer`          | `not null`
# **`response`**         | `string(255)`      |
# **`call_attempt_id`**  | `integer`          |
# **`campaign_id`**      | `integer`          |
#
# ### Indexes
#
# * `call_attempt_id`:
#     * **`call_attempt_id`**
#     * **`id`**
# * `voter_id`:
#     * **`voter_id`**
#     * **`note_id`**
#
