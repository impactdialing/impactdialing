require "spec_helper"

describe Caller do
  include Rails.application.routes.url_helpers

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
    caller = Factory(:caller, :account => user.account)
    campaign = Factory(:campaign, :account => user.account)
    TwilioClient.stub_chain(:instance, :account, :calls, :create).and_return(mock(:response, :sid => sid))
    session = caller.callin(campaign, 5463459043)
    session.sid.should == sid
    session.campaign.should == campaign
  end

  it "asks for pin" do
    Caller.ask_for_pin.should == Twilio::Verb.new do |v|
      v.gather(:numDigits => 5, :timeout => 10, :action => identify_caller_url(:host => Settings.host, :attempt => 1), :method => "POST") do
        v.say "Please enter your pin."
      end
    end.response
  end

  it "asks for pin again" do
    Caller.ask_for_pin(1).should == Twilio::Verb.new do |v|
      v.gather(:numDigits => 5, :timeout => 10, :action => identify_caller_url(:host => Settings.host, :attempt => 2), :method => "POST") do
        v.say "Incorrect Pin. Please enter your pin."
      end
    end.response
  end

  it do
    Factory(:caller)
    should validate_uniqueness_of :email
  end
end
