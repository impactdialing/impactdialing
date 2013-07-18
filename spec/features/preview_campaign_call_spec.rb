require "integration_spec_helper"
require "twilio_helper"
require "twilio_proxy"
require "pusher-fake_helper"
require 'rack/test'



describe "PreviewCampaignCall" do
  include TwilioHelper
  include Capybara::DSL
  include Rack::Test::Methods
      before(:each) do
        @account = Factory(:account, subscription_name: "Manual", activated: true, card_verified: true)
        @script = Factory(:script)
        @script_text = Factory(:script_text, script_id: @script.id, content: "This is a script text", script_order: 1)
        @question = Factory(:question, script_id: @script.id, text: "Whats the question?", script_order: 2)
        @possible_response = Factory(:possible_response, question_id: @question.id, keypad: 1, value: "Test", retry:false,
          possible_response_order: 1)
        @note = Factory(:note, script_id: @script.id, note: "Whats your note?", script_order: 3)
        @campaign = Factory(:preview, account: @account, script: @script, caller_id: "2525732146")
        @trasnfer = Factory(:transfer, label: "Nikhil Warm", phone_number: "1234567890", transfer_type: "warm",
          script_id: @script.id)
        @caller = Factory(:caller, account: @account, campaign: @campaign, email: "nikhil1@impact.com", password: "password")
            voter_list = Factory(:voter_list, name: "test_integration", account: @account, active: true, campaign: @campaign,
        enabled: true)
        voter = Factory(:voter, Phone: "6578889655", campaign: @campaign, account: @account, active: true,
        status: "Not called", voter_list: voter_list)
         visit "/caller/login"
      @twilio_proxy = TwilioProxy.new
      page.should have_content('Log in')
      fill_in "email", with: @caller.email
      fill_in "password", with: @caller.password
      click_link_or_button 'Log in'
      @pin = find("#callin-pin").text
    end


  describe "on start calling" , type: "feature" do

    xit "dial skip and stop calling button should be visible", js: true do
      click_link 'Start calling'
      browser = Rack::Test::Session.new(Rack::MockSession.new(Capybara.app))
      browser.post "/identify_caller", :Digits=> @pin, :attempt=> "1"
      caller_session = @caller.caller_sessions.last
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
      browser = Rack::Test::Session.new(Rack::MockSession.new(Capybara.app))
      browser.post "/identify_caller", :Digits=> @pin, :attempt=> "1"
      caller_session = @caller.caller_sessions.last
      caller_session.update_attributes(sid: "12334")
      click_link "Stop calling"
      browser.post "/caller/end_session", :CallSid=> "12334"
      find(:css, "#start-calling").should be_visible
    end

    xit "should dial and redirect to no funds if account not funded",js: true do
      # @account.update_attributes(subscription_name: "Per Caller")
      click_link 'Start calling'
      browser = Rack::Test::Session.new(Rack::MockSession.new(Capybara.app))
      browser.post "/identify_caller", :Digits=> @pin, :attempt=> "1"
      caller_session = @caller.caller_sessions.last
      click_link 'Dial'
      # PreviewPowerDialJob.new.perform(caller_session.id, @voter.id)
    end

    xit "hangup and show submit response buttons",js: true do
      click_link 'Start calling'
      sleep 5.seconds
      click_link 'Dial'
      sleep 10.seconds
      click_link 'Hang up'
      sleep 5.seconds
      find(:css, "#submit_and_keep_call").should be_visible
      find(:css, "#submit_and_stop_call").should be_visible
    end

    xit "submit and stop calling should show start calling button",js: true do
      click_link 'Start calling'
      sleep 5.seconds
      click_link 'Dial'
      sleep 10.seconds
      click_link 'Hang up'
      sleep 5.seconds
      click_link 'Submit and stop calling'
      sleep 20.seconds
      find(:css, "#start-calling").should be_visible
    end
    xit "submit results and move to next call",js: true do
      click_link 'Start calling'
      sleep 5.seconds
      click_link 'Dial'
      sleep 10.seconds
      click_link 'Hang up'
      sleep 5.seconds
      click_link 'Submit and keep calling'
      sleep 20.seconds
      find(:css, "#start-calling").should be_visible
    end
  end

end