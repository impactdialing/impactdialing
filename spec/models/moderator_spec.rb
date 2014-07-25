require 'spec_helper'

describe Moderator, :type => :model do
  xit "switch from eavesdrop to breakin and vice versa" do
    caller_session = create(:caller_session)
    moderator = create(:moderator, :call_sid => "121213", :caller_session => caller_session)
    http_response = double(HTTParty::Response)
    allow(Twilio::Conference).to receive(:list).with({"FriendlyName" => caller_session.session_key})
    allow(conferences).to receive(:parsed_response).and_return({"TwilioResponse"=>{"Conferences"=>{"Conference"=>{"Sid"=>"CFadf94e58259b8cdd13b711ad2d079820", "AccountSid"=>"AC422d17e57a30598f8120ee67feae29cd", "FriendlyName"=>"f71489ed2375c77db54ed9112b95d3901d5e48ce", "Status"=>"completed", "DateCreated"=>"Mon, 21 Nov 2011 09:20:54 +0000", "ApiVersion"=>"2010-04-01", "DateUpdated"=>"Mon, 21 Nov 2011 09:22:28 +0000", "Uri"=>"/2010-04-01/Accounts/AC422d17e57a30598f8120ee67feae29cd/Conferences/CFadf94e58259b8cdd13b711ad2d079820", "SubresourceUris"=>{"Participants"=>"/2010-04-01/Accounts/AC422d17e57a30598f8120ee67feae29cd/Conferences/CFadf94e58259b8cdd13b711ad2d079820/Participants"}}, "page"=>"0", "numpages"=>"1", "pagesize"=>"50", "total"=>"1", "start"=>"0", "end"=>"0", "uri"=>"/2010-04-01/Accounts/AC422d17e57a30598f8120ee67feae29cd/Conferences?FriendlyName=f71489ed2375c77db54ed9112b95d3901d5e48ce", "firstpageuri"=>"/2010-04-01/Accounts/AC422d17e57a30598f8120ee67feae29cd/Conferences?FriendlyName=f71489ed2375c77db54ed9112b95d3901d5e48ce&Page=0&PageSize=50", "previouspageuri"=>"", "nextpageuri"=>"", "lastpageuri"=>"/2010-04-01/Accounts/AC422d17e57a30598f8120ee67feae29cd/Conferences?FriendlyName=f71489ed2375c77db54ed9112b95d3901d5e48ce&Page=0&PageSize=50"}}})
    expect(Twilio::Conference).to receive(:unmute_participant).with("CFadf94e58259b8cdd13b711ad2d079820", moderator.call_sid).twice
    expect(Twilio::Conference).to receive(:mute_participant).with("CFadf94e58259b8cdd13b711ad2d079820", moderator.call_sid).once
    moderator.switch_monitor_mode(caller_session, "eavesdrop")
    moderator.switch_monitor_mode(caller_session, "eavesdrop")
    moderator.switch_monitor_mode(caller_session, "breakin")
  end
  
 
end

# ## Schema Information
#
# Table name: `moderators`
#
# ### Columns
#
# Name                     | Type               | Attributes
# ------------------------ | ------------------ | ---------------------------
# **`id`**                 | `integer`          | `not null, primary key`
# **`caller_session_id`**  | `integer`          |
# **`call_sid`**           | `string(255)`      |
# **`created_at`**         | `datetime`         |
# **`updated_at`**         | `datetime`         |
# **`session`**            | `string(255)`      |
# **`active`**             | `string(255)`      |
# **`account_id`**         | `integer`          |
#
# ### Indexes
#
# * `active_moderators`:
#     * **`session`**
#     * **`active`**
#     * **`account_id`**
#     * **`created_at`**
# * `index_active_moderators`:
#     * **`account_id`**
#     * **`active`**
#     * **`created_at`**
#
