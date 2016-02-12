require 'rails_helper'

RSpec::Matchers.define :have_script_text do |script_text|
  match do |actual|
    within('.js-script-text > textarea') do
      expect(page).to have_content(script_text_1.content)
    end
  end
end

RSpec::Matchers.define :have_question do |question|
  match do |actual|
    within('.js-script-question') do
      expect(page.find('input[type="text"]').value).to eq question.text
    end
  end
end
RSpec::Matchers.define :have_possible_response do |n, possible_response|
  match do |actual|
    within("table.possible_response:nth-child(#{n}) .js-script-possible-response > .js-script-possible-response-value") do
      expect(page.find('input[type="text"]').value).to eq possible_response.value
    end
  end
end

RSpec::Matchers.define :have_note do |note|
  match do |actual|
    within('.js-script-note') do
      expect(page.find('input[type="text"]').value).to eq note.note
    end
  end
end

describe 'Save a copy of an existing Script under a new name', type: :feature, js: true do
  def save_duplicate
    visit client_scripts_path
    click_on 'Duplicate'
  end

  let(:user){ create(:user) }
  let(:account){ user.account }
  let(:script) do
    create(:script, {
      account: account,
      name: 'The Original'
    })
  end

  before do
    web_login_as(user)
  end

  context 'SelectedFields' do
    let(:system_fields){ VoterList::VOTER_DATA_COLUMNS.values }
    let(:custom_fields) do
      create_list(:bare_custom_voter_field, 5, account: account)
    end
    before do
      script.update_attributes!({
        voter_fields: (system_fields + custom_fields.map(&:name)).to_json
      })
      save_duplicate
    end

    it 'preserves selected voter fields' do
      expected_fields = (system_fields + custom_fields.map(&:name))

      expected_fields.each_with_index do |field,index|
        el = page.find("#script_voter_field_#{index}")
        expect(el.value).to eq field
        expect(el).to be_checked
      end
    end
  end

  context 'ScriptTexts' do
    let!(:script_text){ create(:bare_script_text, script: script) }

    it 'copies ScriptText content' do
      save_duplicate

      expect(page).to have_script_text script_text
    end
  end

  context 'Notes' do
    let!(:note){ create(:bare_note, script: script) }

    it 'copies Note fields' do
      save_duplicate

      expect(page).to have_note(note)
    end
  end

  context 'Transfers' do
    let!(:warm){ create(:bare_transfer, :warm, script: script) }
    let!(:cold){ create(:bare_transfer, :cold, script: script) }

    it 'copies Transfers (warm & cold)' do
      save_duplicate

      within('fieldset.transfers_fields') do
        expect(page.find("input[type=\"text\"][name=\"script[transfers_attributes][0][label]\"]").value).to eq(warm.label)
        expect(page.find("input[type=\"text\"][name=\"script[transfers_attributes][0][phone_number]\"]").value).to eq(warm.phone_number)
        expect(page.find("input[type=\"text\"][name=\"script[transfers_attributes][1][label]\"]").value).to eq(cold.label)
        expect(page.find("input[type=\"text\"][name=\"script[transfers_attributes][1][phone_number]\"]").value).to eq(cold.phone_number)
      end
    end
  end

  context 'Questions & PossibleResponses' do
    let!(:question){ create(:bare_question, script: script) }
    let!(:possible_response){ create(:bare_possible_response, question: question) }

    before do
      save_duplicate
    end

    it 'copies Questions' do
      expect(page).to have_question(question)
    end

    it 'copies PossibleResponses' do
      expect(page).to have_possible_response(2, possible_response)
    end
  end

  context 'Ordering' do
    let!(:script_text_1){ create(:bare_script_text, script: script, script_order: 1) }
    let!(:note_1){ create(:bare_note, script: script, script_order: 2) }
    let!(:question_1){ create(:bare_question, script: script, script_order: 3) }
    let!(:possible_response_1){ create(:bare_possible_response, question: question_1, possible_response_order: 1) }
    let!(:possible_response_2){ create(:bare_possible_response, question: question_1, possible_response_order: 2) }
    let!(:script_text_2){ create(:bare_script_text, script: script, script_order: 4) }
    let!(:note_2){ create(:bare_note, script: script, script_order: 5) }
    let!(:question_2){ create(:bare_question, script: script, script_order: 6) }
    let!(:possible_response_3){ create(:bare_possible_response, question: question_2, possible_response_order: 1) }
    let!(:possible_response_4){ create(:bare_possible_response, question: question_2, possible_response_order: 2) }

    before do
      save_duplicate
    end

    it 'is preserved for ScripTexts, Notes, Questions & PossibleResponses' do
      fieldset_css = -> (n) { "fieldset.orderable_element:nth-child(#{n})" }

      within(fieldset_css.call(1)) do
        expect(page).to have_script_text(script_text_1)
      end
      within(fieldset_css.call(2)) do
        expect(page).to have_note(note_1)
      end
      within(fieldset_css.call(3)) do
        expect(page).to have_question(question_1)
        expect(page).to have_possible_response(2, possible_response_1)
        expect(page).to have_possible_response(3, possible_response_2)
      end
      within(fieldset_css.call(4)) do
        expect(page).to have_script_text(script_text_2)
      end
      within(fieldset_css.call(5)) do
        expect(page).to have_note(note_2)
      end
      within(fieldset_css.call(6)) do
        expect(page).to have_question(question_2)
        expect(page).to have_possible_response(2, possible_response_3)
        expect(page).to have_possible_response(3, possible_response_4)
      end
    end
  end
end
