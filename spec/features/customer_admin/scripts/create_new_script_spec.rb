require 'rails_helper'

describe 'Create a new Script', type: :feature, js: true do
  before(:all) do
    CapybaraConfig.switch_to_webkit
  end

  let(:user){ create(:user) }
  let(:account){ user.account }

  before do
    web_login_as(user)
    visit client_scripts_path
    click_on 'Add new script'
  end

  it 'displays a success message for valid scripts' do
    fill_in 'Script name', with: 'Ode to script.aculo.us'
    check 'Phone'
    check 'LastName'
    check 'FirstName'
    fill_in 'script_script_texts_attributes_0_content', with: 'It was great, it was new, now it is no longer...'
    fill_in 'script_questions_attributes_0_text', with: 'What happened to scriptaculous?'
    click_on 'New response'
    
    # fill_in 'script_questions_attributes_0_possible_responses_attributes_1_value', with: 'Meteoric catastrophe'
    within('.possible_response_sortable table:last-of-type td:nth-of-type(1)') do
      page.find('input[type="text"]').set('Meteoric catastrophe')
    end
    within('.possible_response_sortable table:last-of-type td:nth-of-type(2)') do
      page.find('input[type="text"]').set(1)
    end
    within('.possible_response_sortable table:last-of-type td:nth-of-type(3)') do
      page.find('input[type="checkbox"]').click
    end

    click_on 'Save'

    expect(page).to have_content 'Script saved'
  end
end
