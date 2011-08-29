require "spec_helper"

describe CallinController do
  describe 'Caller Callin' do

    it "prompts for PIN for a caller calling in" do
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

    end

  end

end
