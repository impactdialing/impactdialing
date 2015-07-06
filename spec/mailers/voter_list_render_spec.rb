require 'spec_helper'

RSpec::Matchers.define :render_completed_email_content do |gather_options|
  match do |actual|
    actual =~ /#{stats[:saved_numbers]} of #{stats[:total_numbers]} unique phone numbers imported successfully./ &&
    actual =~ /#{stats[:saved_leads]} of #{stats[:total_leads]} leads imported successfully./ &&
    actual =~ /Of #{stats[:total_numbers]} numbers:/ &&
    actual =~ /#{stats[:new_numbers]} are new numbers/ &&
    actual =~ /#{stats[:pre_existing_numbers]} numbers had leads added or updated/ &&
    actual =~ /#{stats[:dnc_numbers]} matched numbers in the DNC/ &&
    actual =~ /#{stats[:cell_numbers]} were cell phone numbers/ &&
    actual =~ /Of #{stats[:saved_leads]} leads:/ &&
    actual =~ /#{stats[:new_leads]} are new leads/ &&
    actual =~ /#{stats[:updated_leads]} leads were updated/
  end

  chain :with_nested_say do |say_text|
    @say_texts = [*say_text]
  end
end

describe 'VoterListRender (views/voter_list_mailer/completed)', type: :mailer do
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

  context 'text' do
    it 'renders the text template to a string' do
      expect(template.to_s).to render_completed_email_content
    end
  end

  context 'html' do
    it 'renders the html template to a string' do
      expect(template.to_s).to render_completed_email_content
    end
  end
end
