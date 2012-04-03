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

    it "verifies the logged in caller by session pin" do
      pin = rand.to_s[2..6]
      caller = Factory(:caller, :account => account, :campaign => campaign)
      Factory(:caller_identity, :caller => caller, :session_key => 'key' , pin: pin)
      Moderator.stub!(:caller_connected_to_campaign)
      post :identify, Digits: pin
      assigns(:caller).should == caller
    end

    it "updates a caller session on pin verification" do
      pin = rand.to_s[2..6]
      call_sid = "asdflkjh"
      caller = Factory(:caller, :campaign => campaign, :account => account)
      Factory(:caller_identity, :caller => caller, :session_key => 'key' , pin: pin)
      post :identify, :Digits => pin, :CallSid => call_sid
      caller.caller_sessions.last.sid.should == call_sid
    end

    it "asks the user to hold" do
      get :hold
      response.body.should == Caller.hold
    end

    it "Prompts on incorrect pin" do
      pin = rand.to_s[2..6]
      CallerIdentity.stub(:find_by_pin).and_return(nil)
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
      CallerIdentity.stub(:find_by_pin).and_return(nil)
      post :identify, :Digits => pin, :attempt => 3
      response.body.should == Twilio::Verb.new do |v|
        v.say "Incorrect Pin."
        v.hangup
      end.response
    end

    
    it "creates a conference for a caller" do
      pin = rand.to_s[2..6]
      call_sid = "asdflkjh"
      caller = Factory(:caller, :campaign => campaign, :account => account)
      caller_identity = Factory(:caller_identity, caller: caller, :session_key => 'key' , pin: pin)
      session = Factory(:caller_session, :caller => caller, :campaign => campaign, :session_key => 'key')
      CallerIdentity.should_receive(:find_by_pin).and_return(caller_identity)
      caller_identity.should_receive(:caller).and_return(caller)
      caller.should_receive(:create_caller_session).and_return(session)
      Moderator.stub!(:caller_connected_to_campaign).with(caller, campaign, session)
      caller.stub(:is_on_call?).and_return(false)
      post :identify, :Digits => pin, :CallSid => call_sid
      response.body.should == session.start
    end
    
    it "not start a conference if caller is already on call" do
      pin = rand.to_s[2..6]
      caller = Factory(:caller, :campaign => campaign, :account => account)
      older_session = Factory(:caller_session, :caller => caller, :campaign => campaign, :session_key => 'key', on_call: true)
      caller_identity = Factory(:caller_identity, :caller => caller, :session_key => 'key' , pin: pin)
      CallerIdentity.should_receive(:find_by_pin).and_return(caller_identity)
      caller.should_receive(:create_caller_session).and_return(session)

      Moderator.stub!(:caller_connected_to_campaign).with(caller, campaign, session)
      caller.stub(:is_on_call?).and_return(true)
      post :identify, :Digits => pin
      response.body.should == caller.already_on_call
    end
    
    
    it "ask caller to select instructions choice, if caller is phones-only" do
      pin = rand.to_s[2..6]      
      phones_only_caller = Factory(:caller, :account => account, :is_phones_only => true, :campaign => campaign, pin: pin)
      session = Factory(:caller_session, :caller => phones_only_caller, :campaign => campaign, :session_key => 'key')
      Caller.should_receive(:find_by_pin).and_return(phones_only_caller)
      phones_only_caller.stub_chain(:caller_sessions, :create).and_return(session)
      Moderator.stub!(:caller_connected_to_campaign)
      session.should_not_receive(:start)
      post :identify, :Digits => pin
      response.body.should == phones_only_caller.ask_instructions_choice(session)
    end
    

  end


end
