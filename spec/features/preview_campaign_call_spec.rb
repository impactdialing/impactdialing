require "integration_spec_helper"


describe "PreviewCampaignCall" do
  include Capybara::DSL
  Capybara.app_host = 'http://impact.localtunnel.net'
  Capybara.server_port = '8989'
      before(:each) do
        @account = Factory(:account, subscription_name: "Manual", activated: true, card_verified: true)
        @script = Factory(:script)
        @script_text = Factory(:script_text, script_id: @script.id, content: "This is a script text", script_order: 1)
        @question = Factory(:question, script_id: @script.id, text: "Whats the question?", script_order: 2)
        @possible_response = Factory(:possible_response, question_id: @question.id, keypad: 1, value: "Test", retry:false,
          possible_response_order: 1)
        @note = Factory(:note, script_id: @script.id, note: "Whats your note?", script_order: 3)
        @campaign = Factory(:preview, account: @account, script: @script)

        @caller = Factory(:caller, account: @account, campaign: @campaign, email: "nikhil1@impact.com", password: "password")
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


  describe "on start calling" , type: "feature" do
    it "dial skip and stop calling button should be visible",js: true do
      click_link 'Start calling'
      sleep 5.seconds
      find('#call_voter').should have_content('Dial')
      find('#skip_voter').should have_content('Skip')
      find('#stop_calling').should have_content('Stop calling')
      find('#statusdiv').should have_content('Ready for calls')
      find(:css, "#call_voter").should be_visible
      find(:css, "#skip_voter").should be_visible
      find(:css, "#stop_calling").should be_visible

    end

     it "stop calling should refresh the screen",js: true do
      click_link 'Start calling'
      sleep 5.seconds
      click_link "Stop calling"
      sleep 10.seconds
      find(:css, "#start-calling").should be_visible
    end

    it "dial should show hangup and change status",js: true do
      click_link 'Start calling'
      sleep 5.seconds
      click_link 'Dial'
      sleep 10.seconds
      find(:css, "#hangup_call").should be_visible
      find('#statusdiv').should have_content('Call in progress')
    end
  end

end