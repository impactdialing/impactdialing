require 'spec_helper'

RSpec::Matchers.define :render_email_content do |content|
  match do |actual|
    content.map do |regex|
      actual =~ regex
    end.all?{|bool| bool}
  end

  failure_message do |actual|
    "expected:\n#{content}\n" +
    "got:\n#{actual}\n"
  end
end

describe 'VoterListRender (views/voter_list_mailer/completed)', type: :mailer do
  let(:renderer){ VoterListRender.new }

  describe '#completed' do
    let(:stats) do
      {
        total_rows: 7,
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
        invalid_rows: [],
        use_custom_id: true
      }
    end
    let(:content) do 
      [
        /Your list contained:/,
        /#{stats[:total_rows]} rows of data/,
        /#{stats[:saved_numbers]} valid unique phone numbers/,
        /#{stats[:saved_leads]} valid leads/,
        /#{stats[:saved_numbers] - stats[:dnc_numbers] - stats[:cell_numbers]} of #{stats[:saved_numbers]} unique phone numbers are available for dials./,
        /Of #{stats[:saved_numbers]} valid unique phone numbers:/,
        /#{stats[:new_numbers]} are new numbers/,
        /#{stats[:pre_existing_numbers]} numbers had leads added or updated/,
        /#{stats[:dnc_numbers]} matched numbers in the DNC/,
        /#{stats[:cell_numbers]} were cell phone numbers/,
        /#{stats[:saved_leads]} of #{stats[:total_rows]} leads imported successfully./,
        /Of #{stats[:saved_leads]} leads:/,
        /#{stats[:new_leads]} are new leads/,
        /#{stats[:updated_leads]} leads were updated/
      ]
    end
    context 'text' do
      let(:template){ renderer.completed(:text, stats) }
      it 'renders the text template to a string' do
        expect(template.to_s).to render_email_content(content)
      end
    end

    context 'html' do
      let(:template){ renderer.completed(:html, stats) }
      it 'renders the html template to a string' do
        expect(template.to_s).to render_email_content(content)
      end
    end
  end

  describe '#pruned_numbers' do
    let(:stats) do
      {
        total_rows: 12,
        total_numbers: 12,
        removed_numbers: 10,
        invalid_rows: []
      }
    end
    let(:content) do
      [
        /#{stats[:removed_numbers]} phone numbers were removed from your campaign./,
        /Your list contained:/,
        /#{stats[:total_rows]} rows of data/,
        /#{stats[:total_numbers]} valid phone numbers/
      ]
    end
    context 'text' do
      let(:template){ renderer.pruned_numbers(:text, stats) }
      it 'renders the text template to a string' do
        expect(template.to_s).to render_email_content(content)
      end
    end
    context 'html' do
      let(:template){ renderer.pruned_numbers(:html, stats) }
      it 'renders the html template to a string' do
        expect(template.to_s).to render_email_content(content)
      end
    end
  end

  describe '#pruned_leads' do
    let(:stats) do
      {
        total_rows: 12,
        total_leads: 12,
        removed_numbers: 3,
        removed_leads: 8,
        invalid_rows: [],
        invalid_custom_ids: 0
      }
    end
    let(:content) do
      [
        /#{stats[:removed_leads]} leads and #{stats[:removed_numbers]} phone numbers were removed from your campaign./,
        /Your list contained:/,
        /#{stats[:total_rows]} rows of data/,
        /#{stats[:total_leads]} valid lead IDs/
      ]
    end

    context 'text' do
      let(:template){ renderer.pruned_leads(:text, stats) }
      it 'renders the text template to string' do
        expect(template.to_s).to render_email_content(content)
      end
    end
    context 'html' do
      let(:template){ renderer.pruned_leads(:html, stats) }
      it 'renders the text template to string' do
        expect(template.to_s).to render_email_content(content)
      end
    end
  end
end
