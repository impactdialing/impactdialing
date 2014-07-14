require 'spec_helper'

describe 'routes for CallCenter (draft)', :type => :routing do
  it 'GET /call_center/api/twilio_token => station#twilio_token' do
    expect({get: '/call_center/api/twilio_token'}).to route_to(controller: 'callers/station', action: 'twilio_token')
  end

  it 'POST /call_center/api/call_station => station#create' do
    expect({post: '/call_center/api/call_station'}).to route_to(controller: 'callers/station', action: 'create')
  end

  it 'GET /call_center/api/survey_fields => station#survey_fields' do
    expect({get: '/call_center/api/survey_fields'}).to route_to(controller: 'callers/station', action: 'script')
  end

  [
    'start_calling', 'call_voter', 'skip_voter'
  ].each do |action|
    it "POST /call_center/api/:id/#{action} => caller##{action}" do
      expect({post: "/call_center/api/1/#{action}"}).to route_to(controller: 'caller', action: action, id: '1')
    end
  end

  it "POST /call_center/api/:id/stop_calling => calls#stop_calling" do
    expect({post: "/call_center/api/1/stop_calling"}).to route_to(controller: 'caller', action: 'stop_calling', id: '1')
  end

  [
    'hangup', 'submit_result', 'submit_result_and_stop'
  ].each do |action|
    it "POST /call_center/api/:id/#{action} => calls##{action}" do
      expect({post: "/call_center/api/1/#{action}"}).to route_to(controller: 'calls', action: action, id: '1')
    end
  end
end
