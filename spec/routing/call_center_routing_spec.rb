require 'spec_helper'

describe 'routes for CallCenter (draft)' do
  it 'POST /call_center/api/token => campaign_calls#token' do
    {post: '/call_center/api/token'}.should route_to(controller: 'callers/campaign_calls', action: 'token')
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
