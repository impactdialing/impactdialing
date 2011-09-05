require "spec_helper"

describe CallinController do
  describe 'Caller Calling In' do

    it "prompts for PIN for a caller " do
      post :create
      resp = Twilio::Verb.new do |v|
        v.gather(:numDigits => 5, :timeout => 10, :action => identify_caller_url(:host => Settings.host), :method => "POST") do
          v.say "Please enter your pin"
        end
      end.response
      response.body.should == resp
    end

    it "verifies the logged in caller by pin" do
      pin = rand.to_s[2..6]
      caller = Factory(:caller, :pin => pin)
      Caller.stub(:find_by_pin).and_return(caller)
      post :identify, :Digits => pin
      assigns(:caller).should == caller
    end

    it "creates a caller session on pin verification" do
      pin = rand.to_s[2..6]
      caller = Factory(:caller, :pin => pin)
      Caller.stub(:find_by_pin).and_return(caller)
      post :identify, :Digits => pin
      session = assigns(:session)
      session.caller.should == caller
      session.available_for_call.should be_false
      session.on_call.should be_false
    end

    it "Prompts on incorrect pin" do
      pin = rand.to_s[2..6]
      Caller.stub(:find_by_pin).and_return(nil)
      post :identify, :Digits => pin
      response.body.should == Twilio::Verb.new do |v|
        v.gather(:numDigits => 5, :timeout => 10, :action => identify_caller_url(:host => Settings.host, :attempt => 1), :method => "POST") do
          v.say "Incorrect Pin. Please enter your pin."
        end
      end.response
    end

    it "Hangs up on incorrect pin after the third attempt" do
      pin = rand.to_s[2..6]
      Caller.stub(:find_by_pin).and_return(nil)
      post :identify, :Digits => pin, :attempt => 2
      response.body.should == Twilio::Verb.new do |v|
        v.say "Incorrect Pin."
        v.hangup
      end.response
    end

  end


end
