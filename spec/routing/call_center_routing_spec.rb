require 'spec_helper'

describe 'routes for CallCenter (draft)' do
  it 'GET /call_center/api/twilio_token => campaign_calls#twilio_token' do
    {get: '/call_center/api/twilio_token'}.should route_to(controller: 'callers/campaign_calls', action: 'twilio_token')
  end

  it 'POST /call_center/api/call_station => campaign_calls#call_station' do
    {post: '/call_center/api/call_station'}.should route_to(controller: 'callers/campaign_calls', action: 'call_station')
  end

  it 'GET /call_center/api/script => campaign_calls#script' do
    {get: '/call_center/api/script'}.should route_to(controller: 'callers/campaign_calls', action: 'script')
  end

  [
    'start_calling', 'submit_response', 'call_voter', 'stop_calling',
    'skip_voter', 'kick'
  ].each do |action|
    it "POST /call_center/api/:id/#{action} => caller##{action}" do
      {post: "/call_center/api/1/#{action}"}.should route_to(controller: 'caller', action: action, id: '1')
    end
  end
end
