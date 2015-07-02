require 'spec_helper'

describe 'VoterListRender', type: :mailer do
  let(:stats) do
    {
      saved_numbers: 5,
      total_numbers: 7,
      saved_leads: 3,
      total_leads: 5,
      new_numbers: 3,
      pre_existing_numbers: 2,
      dnc_numbers: 1,
      cell_numbers: 1,
      new_leads: 3,
      updated_leads: 0,
      use_custom_id: true
    }
  end
  let(:renderer){ VoterListRender.new }
  let(:template){ renderer.completed(:text, stats) }

  it 'renders the text template to a string: views/voter_list_mailer/completed' do
    t = template.to_s

    expect(t).to match(/#{stats[:saved_numbers]} of #{stats[:total_numbers]} numbers imported successfully./)
    expect(t).to match(/#{stats[:saved_leads]} of #{stats[:total_leads]} leads imported successfully./)
    expect(t).to match(/Of #{stats[:saved_numbers]} numbers:/)
    expect(t).to match(/- #{stats[:new_numbers]} are new numbers/)
    expect(t).to match(/- #{stats[:pre_existing_numbers]} numbers had leads added or updated/)
    expect(t).to match(/- #{stats[:dnc_numbers]} matched numbers in the DNC/)
    expect(t).to match(/- #{stats[:cell_numbers]} were cell phone numbers/)
    expect(t).to match(/Of #{stats[:saved_leads]} leads:/)
    expect(t).to match(/- #{stats[:new_leads]} are new leads/)
    expect(t).to match(/- #{stats[:updated_leads]} leads were updated/)
  end
end
