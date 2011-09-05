require "spec_helper"

describe Caller do
  include ActionController::UrlWriter

  let(:user) { Factory(:user) }
  it "restoring makes it active" do
    caller_object = Factory(:caller, :active => false)
    caller_object.restore
    caller_object.active?.should == true
  end

  it "sorts by the updated date" do
    Caller.record_timestamps = false
    older_caller = Factory(:caller).tap { |c| c.update_attribute(:updated_at, 2.days.ago) }
    newer_caller = Factory(:caller).tap { |c| c.update_attribute(:updated_at, 1.day.ago) }
    Caller.record_timestamps = true
    Caller.by_updated.all.should == [newer_caller, older_caller]
  end

  it "lists active callers" do
    active_caller = Factory(:caller, :active => true)
    inactive_caller = Factory(:caller, :active => false)
    Caller.active.should == [active_caller]
  end

  it "calls in to the campaign" do
    Twilio::REST::Client
    sid = "gogaruko"
    caller = Factory(:caller, :user => user)
    campaign = Factory(:campaign, :user => user)
    TwilioClient.stub_chain(:instance, :account, :calls, :create).and_return({"TwilioResponse" => {"Call" => {"Sid" => sid}}})
    session = caller.callin(campaign, 5463459043)
    session.sid.should == sid
    session.campaign.should == campaign
  end

  it "asks for pin again" do
    Caller.ask_for_pin(nil.to_i).should == Twilio::Verb.new do |v|
        v.gather(:numDigits => 5, :timeout => 10, :action => identify_caller_url(:host => Settings.host, :attempt => 1), :method => "POST") do
          v.say "Incorrect Pin. Please enter your pin."
        end
      end.response
  end

end
