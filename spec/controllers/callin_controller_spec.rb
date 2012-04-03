require "spec_helper"

describe CallinController do
  describe 'Caller Calling In' do
    let(:account) { Factory(:account, :activated => true, :subscription_name => "Manual") }
    let(:campaign) { Factory(:campaign, :account => account, :start_time => Time.new("2000-01-01 01:00:00"), :end_time => Time.new("2000-01-01 23:00:00"))}
    
    it "prompts for PIN for a caller " do
      post :create
      resp = Twilio::Verb.new do |v|
        3.times do
          v.gather(:numDigits => 5, :timeout => 10, :action => identify_caller_url(:host => Settings.host, :port => Settings.port,  :attempt => 1), :method => "POST") do
            v.say "Please enter your pin."
          end
        end
      end.response
      response.body.should == resp
    end

    it "verifies the logged in caller by pin" do
      pin = rand.to_s[2..6]
      caller = Factory(:caller, :pin => pin, :account => account, :campaign => campaign)
      session = Factory(:caller_session, :caller => caller, :campaign => campaign, :session_key => "samplekey")
      Caller.stub(:find_by_pin).and_return(caller)
      Moderator.stub!(:caller_connected_to_campaign)
      caller.stub_chain(:caller_sessions, :create).and_return(session)
      post :identify, :Digits => pin
      assigns(:caller).should == caller
    end

    it "creates a caller session on pin verification" do
      pin = rand.to_s[2..6]
      call_sid = "asdflkjh"
      caller = Factory(:caller, :pin => pin, :campaign => campaign, :account => account)
      Caller.stub(:find_by_pin).and_return(caller)
      post :identify, :Digits => pin, :CallSid => call_sid
      caller_session = assigns(:session)
      caller_session.caller.should == caller
      caller_session.available_for_call.should be_true
      caller_session.on_call.should be_true
      caller_session.session_key.should be
      caller_session.sid.should == call_sid
    end

    it "asks the user to hold" do
      get :hold
      response.body.should == Caller.hold
    end

    it "Prompts on incorrect pin" do
      pin = rand.to_s[2..6]
      Caller.stub(:find_by_pin).and_return(nil)
      post :identify, :Digits => pin, :attempt => "1"
      response.body.should == Twilio::Verb.new do |v|
        3.times do
          v.gather(:numDigits => 5, :timeout => 10, :action => identify_caller_url(:host => Settings.host, :port => Settings.port, :attempt => 2), :method => "POST") do
            v.say "Incorrect Pin. Please enter your pin."
          end
        end
      end.response
    end

    it "Hangs up on incorrect pin after the third attempt" do
      pin = rand.to_s[2..6]
      Caller.stub(:find_by_pin).and_return(nil)
      post :identify, :Digits => pin, :attempt => 3
      response.body.should == Twilio::Verb.new do |v|
        v.say "Incorrect Pin."
        v.hangup
      end.response
    end

    it "Prompts for campaign pin" do
      pin = rand.to_s[2..6]
      caller = Factory(:caller, :pin => pin, :campaign => campaign, :account => account)
      session = Factory(:caller_session, :caller => caller, :campaign => campaign, :session_key => "samplekey")
      caller.stub_chain(:caller_sessions, :create).and_return(session)
      Caller.stub(:find_by_pin).and_return(caller)
      post :identify, :Digits => pin
      response.body.should == session.start
    end
    
    it "creates a conference for a caller" do
      pin = rand.to_s[2..6]
      caller = Factory(:caller, :pin => pin, :campaign => campaign, :account => account)
      session = Factory(:caller_session, :caller => caller, :campaign => campaign, :session_key => 'key')
      caller.stub_chain(:caller_sessions, :create).and_return(session)
      Moderator.stub!(:caller_connected_to_campaign).with(caller, campaign, session)
      Caller.stub(:find_by_pin).and_return(caller)
      post :identify, :Digits => pin
      response.body.should == session.start
    end
    
    it "ask caller to select instructions choice, if caller is phones-only" do
      pin = rand.to_s[2..6]
      
      phones_only_caller = Factory(:caller, :account => account, :is_phones_only => true, :campaign => campaign)
      session = Factory(:caller_session, :caller => phones_only_caller, :campaign => campaign, :session_key => 'key')
      phones_only_caller.stub_chain(:caller_sessions, :create).and_return(session)
      Moderator.stub!(:caller_connected_to_campaign)#.with(phones_only_caller, campaign, session)
      session.should_not_receive(:start)

      Caller.stub(:find_by_pin).and_return(phones_only_caller)
      post :identify, :Digits => pin
      response.body.should == phones_only_caller.ask_instructions_choice(session)
    end

  end


end
