require "spec_helper"

describe CallinController do
  describe 'Caller Calling In' do
    let(:account) { Factory(:account, :activated => true, :subscription_name => "Manual") }
    let(:campaign) { Factory(:predictive, :account => account, :start_time => Time.new("2000-01-01 01:00:00"), :end_time => Time.new("2000-01-01 23:00:00"))}
    
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

  end


end
