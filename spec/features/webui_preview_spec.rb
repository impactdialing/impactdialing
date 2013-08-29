require "integration_spec_helper"
require "twilio_helper"
require "twilio_proxy"
require "pusher-fake_helper"
require 'rack/test'



describe "WebuiPreview" do
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
        @caller = Factory(:caller, account_id: @account.id, campaign: @campaign, email: "nikhil1@impact.com", password: "password")
        @voter_list = Factory(:voter_list, name: "test_integration", account: @account, active: true, campaign: @campaign,
        enabled: true)
        @voter = Factory(:voter, Phone: "6578889655", campaign: @campaign, account: @account, active: true,
        status: "Not called", voter_list: @voter_list)
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

    xit "stop calling should refresh the screen",js: true do
      click_link 'Start calling'
      browser = Rack::Test::Session.new(Rack::MockSession.new(Capybara.app))
      browser.post "/identify_caller", :Digits=> @pin, :attempt=> "1"
      caller_session = @caller.caller_sessions.last
      caller_session.update_attributes(sid: "12334")
      click_link "Stop calling"
      browser.post "/caller/end_session", :CallSid=> "12334"
      find(:css, "#start-calling").should be_visible
    end

    xit "should  read  no funds if account not funded",js: true do
      click_link 'Start calling'
      @account.update_attributes(subscription_name: "Per Caller", subscription_count: 1)
      @caller.update_attributes(account: @account)
      Factory(:payment, amount_paid: 10.00, amount_remaining: 0.00, account: @account)
      browser = Rack::Test::Session.new(Rack::MockSession.new(Capybara.app))
      response = browser.post "/identify_caller", :Digits=> @pin, :attempt=> "1"
      response.body.should eq('<?xml version="1.0" encoding="UTF-8"?><Response><Say>There are no funds available in the account.  Please visit the billing area of the website to add funds to your account.</Say><Hangup/></Response>')
    end

    xit "should  read not activated if account not activated",js: true do
      click_link 'Start calling'
      @account.update_attributes(subscription_name: "Per Caller", activated: false )
      @caller.update_attributes(account: @account)
      Factory(:payment, amount_paid: 10.00, amount_remaining: 0.00, account: @account)
      browser = Rack::Test::Session.new(Rack::MockSession.new(Capybara.app))
      response = browser.post "/identify_caller", :Digits=> @pin, :attempt=> "1"
      response.body.should eq("<?xml version=\"1.0\" encoding=\"UTF-8\"?><Response><Say>Your account has insufficent funds</Say><Hangup/></Response>")
    end

    xit "should  read not subscription level reached if subscription limit reached",js: true do
      click_link 'Start calling'
      @account.update_attributes(subscription_name: "Per Caller", subscription_count: 0, activated: true)
      @caller.update_attributes(account: @account)
      Factory(:payment, amount_paid: 10.00, amount_remaining: 10.00, account: @account)
      browser = Rack::Test::Session.new(Rack::MockSession.new(Capybara.app))
      response = browser.post "/identify_caller", :Digits=> @pin, :attempt=> "1"
      response.body.should eq("<?xml version=\"1.0\" encoding=\"UTF-8\"?><Response><Say>The maximum number of callers for this account has been reached. Wait for another caller to finish, or ask your administrator to upgrade your account.</Say><Hangup/></Response>")
    end

    xit "should  say time period exceeded if calling out of assigned hours",js: true do
      click_link 'Start calling'
      @account.update_attributes(subscription_name: "Per Caller", subscription_count: 1, activated: true)
      @caller.update_attributes(account: @account)
      @campaign.update_attributes(start_time: (Time.now - 2.hours), end_time: (Time.now - 1.hours))
      Factory(:payment, amount_paid: 10.00, amount_remaining: 10.00, account: @account)
      browser = Rack::Test::Session.new(Rack::MockSession.new(Capybara.app))
      response = browser.post "/identify_caller", :Digits=> @pin, :attempt=> "1"
      response.body.should eq("<?xml version=\"1.0\" encoding=\"UTF-8\"?><Response><Say>You can only call this campaign between 1 PM and 2 PM. Please try back during those hours.</Say><Hangup/></Response>")
    end

    xit "should  say caller already on call if another caller is dialing with same creds",js: true do
      another_caller_session = Factory(:webui_caller_session, caller: @caller, campaign: @campaign, on_call: true)
      click_link 'Start calling'
      @account.update_attributes(subscription_name: "Per Caller", subscription_count: 2, activated: true)
      @caller.update_attributes(account: @account)
      Factory(:payment, amount_paid: 10.00, amount_remaining: 10.00, account: @account)
      browser = Rack::Test::Session.new(Rack::MockSession.new(Capybara.app))
      response = browser.post "/identify_caller", :Digits=> @pin, :attempt=> "1"
      response.body.should eq("<?xml version=\"1.0\" encoding=\"UTF-8\"?><Response><Say>Another user is logged in as this caller. Only one user may log in as the same caller at the same time.</Say><Hangup/></Response>")
    end
  end

  describe "on dial" , type: "feature" do

    xit "hangup and show submit response buttons for call answered by human",js: true do
      click_link 'Start calling'
      browser = Rack::Test::Session.new(Rack::MockSession.new(Capybara.app))
      browser.post "/identify_caller", :Digits=> @pin, :attempt=> "1"
      caller_session = @caller.caller_sessions.last
      click_link 'Dial'
      sleep 5.seconds
      call = Call.first
      browser.post "/calls/#{call.id}/incoming?campaign_type=#{@campaign.type}", { answered_by:  "human", call_status: "in-progress"}
      click_link 'Hang up'
      browser.post "/calls/#{call.id}/disconnected"
      find(:css, "#submit_and_keep_call").should be_visible
      find(:css, "#submit_and_stop_call").should be_visible
    end

    xit "redirect caller to next voter if call answered by machine",js: true do
      another_voter = Factory(:voter, Phone: "6578889655", campaign: @campaign, account: @account, active: true,
        status: "Not called", voter_list: @voter_list)
      click_link 'Start calling'
      browser = Rack::Test::Session.new(Rack::MockSession.new(Capybara.app))
      browser.post "/identify_caller", :Digits=> @pin, :attempt=> "1"
      caller_session = @caller.caller_sessions.last
      click_link 'Dial'
      sleep 5.seconds
      call = Call.first
      browser.post "/calls/#{call.id}/incoming?campaign_type=#{@campaign.type}", { answered_by:  "machine", call_status: "in-progress"}
      sleep 2.seconds
      browser.post "/caller/#{@caller.id}/continue_conf"
      find(:css, "#call_voter").should be_visible
      find(:css, "#skip_voter").should be_visible
      find(:css, "#stop_calling").should be_visible
    end

    xit "redirect caller to next voter if call not answered",js: true do
      another_voter = Factory(:voter, Phone: "6578889655", campaign: @campaign, account: @account, active: true,
        status: "Not called", voter_list: @voter_list)
      click_link 'Start calling'
      browser = Rack::Test::Session.new(Rack::MockSession.new(Capybara.app))
      browser.post "/identify_caller", :Digits=> @pin, :attempt=> "1"
      caller_session = @caller.caller_sessions.last
      click_link 'Dial'
      sleep 5.seconds
      call = Call.first
      browser.post "/calls/#{call.id}/call_ended?campaign_type=#{@campaign.type}", {call_status: "no-answer", campaign_type: "Preview"}
      sleep 2.seconds
      browser.post "/caller/#{@caller.id}/continue_conf"
      find(:css, "#call_voter").should be_visible
      find(:css, "#skip_voter").should be_visible
      find(:css, "#stop_calling").should be_visible
    end

    xit "should move to next voter when answer submitted and keep calling",js: true do
      another_voter = Factory(:voter, Phone: "6578889655", campaign: @campaign, account: @account, active: true,
        status: "Not called", voter_list: @voter_list)
      click_link 'Start calling'
      browser = Rack::Test::Session.new(Rack::MockSession.new(Capybara.app))
      browser.post "/identify_caller", :Digits=> @pin, :attempt=> "1"
      caller_session = @caller.caller_sessions.last
      click_link 'Dial'
      sleep 5.seconds
      call = Call.first
      browser.post "/calls/#{call.id}/incoming?campaign_type=#{@campaign.type}", { answered_by:  "human", call_status: "in-progress"}
      click_link 'Hang up'
      browser.post "/calls/#{call.id}/disconnected"
      browser.post "/calls/#{call.id}/call_ended?campaign_type=#{@campaign.type}", {call_status: "completed", campaign_type: "Preview"}
      click_link 'Submit and keep calling'
      browser.post "/caller/#{@caller.id}/continue_conf"
      find(:css, "#call_voter").should be_visible
      find(:css, "#skip_voter").should be_visible
      find(:css, "#stop_calling").should be_visible
    end

    xit "should show start calling when answer submitted and stop calling",js: true do
      another_voter = Factory(:voter, Phone: "6578889655", campaign: @campaign, account: @account, active: true,
        status: "Not called", voter_list: @voter_list)
      click_link 'Start calling'
      browser = Rack::Test::Session.new(Rack::MockSession.new(Capybara.app))
      browser.post "/identify_caller", :Digits=> @pin, :attempt=> "1"
      caller_session = @caller.caller_sessions.last
      caller_session.update_attributes(sid: "12334")
      click_link 'Dial'
      sleep 5.seconds
      call = Call.first
      browser.post "/calls/#{call.id}/incoming?campaign_type=#{@campaign.type}", { answered_by:  "human", call_status: "in-progress"}
      click_link 'Hang up'
      browser.post "/calls/#{call.id}/disconnected"
      browser.post "/calls/#{call.id}/call_ended?campaign_type=#{@campaign.type}", {call_status: "completed", campaign_type: "Preview"}
      click_link 'Submit and stop calling'
      browser.post "/caller/end_session", :CallSid=> "12334"
      find(:css, "#start-calling").should be_visible
    end

  end

end