require "spec_helper"


describe "PreviewCampaignCall" do
  include Capybara::DSL
  Capybara.app_host = 'http://impact.localtunnel.net'
  Capybara.server_port = '8989'

  describe "on start calling" do

    before(:all) do
        @account = Factory(:account, subscription_name: "Manual", activated: true, card_verified: true)
        @script = Factory(:script)
        @script_text = Factory(:script_text, script_id: @script.id, content: "This is a script text", script_order: 1)
        @question = Factory(:question, script_id: @script.id, text: "Whats the question?", script_order: 2)
        @possible_response = Factory(:possible_response, question_id: @question.id, keypad: 1, value: "Test", retry:false,
          possible_response_order: 1)
        @note = Factory(:note, script_id: @script.id, note: "Whats your note?", script_order: 3)

        @campaign = Factory(:preview, account: @account, script: @script)

        @caller = Factory(:caller, account: @account, campaign: @campaign, email: "nikhil@impact.com", password: "password")
            voter_list = Factory(:voter_list, name: "test_integration", account: @account, active: true, campaign: @campaign,
        enabled: true)
        voter = Factory(:voter, Phone: "1239087654", campaign: @campaign, account: @account, active: true,
        status: "Not called", voter_list: voter_list)
        visit "/caller/login"
        page.should have_content('Log in')
        fill_in "email", with: @caller.email
        fill_in "password", with: @caller.password
        click_link_or_button 'Log in'
    end

    it "dial skip and stop calling button should be visible" do
      click_link 'Start calling'
      sleep 5.seconds
      find('#call_voter').should have_content('Dial')
      find('#skip_voter').should have_content('Skip')
      find('#stop_calling').should have_content('Stop calling')
      find('#statusdiv').should have_content('Ready for calls')
      find_link('Dial').visible?
      find_link('Skip').visible?
      find_link('Stop calling').visible?
    end

    it "stop calling should refresh the screen" do
      click_link 'Start calling'
      sleep 5.seconds
      click "Stop calling"
      find_link('Start calling').visible?

    end
  end
end