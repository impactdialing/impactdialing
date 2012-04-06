require 'spec_helper'

describe Moderator do
  xit "switch from eavesdrop to breakin and vice versa" do
    caller_session = Factory(:caller_session)
    moderator = Factory(:moderator, :call_sid => "121213", :caller_session => caller_session)
    http_response = mock(HTTParty::Response)
    Twilio::Conference.stub!(:list).with({"FriendlyName" => caller_session.session_key})
    conferences.stub!(:parsed_response).and_return({"TwilioResponse"=>{"Conferences"=>{"Conference"=>{"Sid"=>"CFadf94e58259b8cdd13b711ad2d079820", "AccountSid"=>"AC422d17e57a30598f8120ee67feae29cd", "FriendlyName"=>"f71489ed2375c77db54ed9112b95d3901d5e48ce", "Status"=>"completed", "DateCreated"=>"Mon, 21 Nov 2011 09:20:54 +0000", "ApiVersion"=>"2010-04-01", "DateUpdated"=>"Mon, 21 Nov 2011 09:22:28 +0000", "Uri"=>"/2010-04-01/Accounts/AC422d17e57a30598f8120ee67feae29cd/Conferences/CFadf94e58259b8cdd13b711ad2d079820", "SubresourceUris"=>{"Participants"=>"/2010-04-01/Accounts/AC422d17e57a30598f8120ee67feae29cd/Conferences/CFadf94e58259b8cdd13b711ad2d079820/Participants"}}, "page"=>"0", "numpages"=>"1", "pagesize"=>"50", "total"=>"1", "start"=>"0", "end"=>"0", "uri"=>"/2010-04-01/Accounts/AC422d17e57a30598f8120ee67feae29cd/Conferences?FriendlyName=f71489ed2375c77db54ed9112b95d3901d5e48ce", "firstpageuri"=>"/2010-04-01/Accounts/AC422d17e57a30598f8120ee67feae29cd/Conferences?FriendlyName=f71489ed2375c77db54ed9112b95d3901d5e48ce&Page=0&PageSize=50", "previouspageuri"=>"", "nextpageuri"=>"", "lastpageuri"=>"/2010-04-01/Accounts/AC422d17e57a30598f8120ee67feae29cd/Conferences?FriendlyName=f71489ed2375c77db54ed9112b95d3901d5e48ce&Page=0&PageSize=50"}}})
    Twilio::Conference.should_receive(:unmute_participant).with("CFadf94e58259b8cdd13b711ad2d079820", moderator.call_sid).twice
    Twilio::Conference.should_receive(:mute_participant).with("CFadf94e58259b8cdd13b711ad2d079820", moderator.call_sid).once
    moderator.switch_monitor_mode(caller_session, "eavesdrop")
    moderator.switch_monitor_mode(caller_session, "eavesdrop")
    moderator.switch_monitor_mode(caller_session, "breakin")
  end
  
  xit " sends pusher event (caller_session_started) to the all the moderators of a particular account " do
    account = Factory(:account)
    moderator1 = Factory(:moderator, :account => account, :session => "s123", :active => true)
    moderator2 = Factory(:moderator, :account => account, :session => "s1234", :active => true)
    moderator3 = Factory(:moderator, :account => account, :session => "s12345", :active => false)
   
    campaign = Factory(:campaign)
    caller_session = Factory(:caller_session)
    caller = Factory(:caller, :account => account)
    channel = mock
    data= {"account_id"=>account.id, "active"=>true, "email"=>"user2@example.com", "id"=>caller.id, "multi_user"=>true, "name"=>"a caller", "password"=>nil, "pin"=>"39046", :campaign_name=>campaign.name, :session_id=>caller_session.id, :campaign_fields=>{:id=>campaign.id, :callers_logged_in=>1, :voters_count=>0, :path=>"/client/campaigns/#{campaign.id}"}}
    channel.should_receive(:trigger_async).with("caller_session_started",data).twice
    Pusher.should_receive(:[]).with(moderator2.session).and_return(channel)
    Pusher.should_receive(:[]).with(moderator1.session).and_return(channel)
    Pusher.should_not_receive(:[]).with(moderator3.session)

    Moderator.caller_connected_to_campaign(caller, campaign, caller_session)
  end
  
  it "should send the event(voter connected) to monitors" do
    account = Factory(:account)
    moderator1 = Factory(:moderator, :account => account, :session => "s123", :active => true)
    moderator2 = Factory(:moderator, :account => account, :session => "s1234", :active => true)
    moderator3 = Factory(:moderator, :account => account, :session => "s12345", :active => false)
    caller = Factory(:caller, :account => account)
    channel = mock
    Pusher.should_receive(:[]).with(moderator1.session).and_return(channel)
    Pusher.should_receive(:[]).with(moderator2.session).and_return(channel)
    channel.should_receive(:trigger_async).with("voter_connected", {}).twice
    Moderator.publish_event(caller, "voter_connected", {})
  end
  
end
