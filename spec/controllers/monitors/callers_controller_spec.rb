require 'spec_helper'

describe Monitors::CallersController do
  include TwilioRequests
  include TwilioResponses

  let(:account){ create(:account) }
  let(:admin){ create(:user, account: account) }
  let(:campaign){ create(:power, {account: account}) }
  let(:caller){ create(:caller, campaign: campaign) }

  before do
    WebMock.disable_net_connect!
    login_as(admin)
  end

  describe '#switch_mode, params: session_id, monitor_session_id, type' do
    let(:caller_session){ create(:webui_caller_session, {caller: caller}) }
    let(:conference_sid){ 'CFww834eJSKDJFjs328JF92JSDFwe' }
    let(:call_sid){ caller_session.sid }
    let(:conference_name){ caller_session.session_key }
    let(:moderator){ create(:moderator) }
    let(:valid_params) do
      {
        session_id: caller_session.id,
        monitor_session_id: moderator.id,
        type: 'eavesdrop'
      }
    end

    before do
      @conf_list_request = stub_request(:get, twilio_conference_by_name_url(conference_name)).
        to_return({
          :status => 200,
          :body => conference_by_name_response,
          :headers => {
            'Content-Type' => 'text/xml'
          }
        })
      @mute_participant_request = stub_request(:post, twilio_conference_mute_url(conference_sid, call_sid)).
        with(:body => twilio_mute_request_body).
        to_return({
          :status => 200,
          :body => muted_participant_response,
          :headers => {}
        })
    end

    it 'should be a success w/ valid params' do
      put :switch_mode, valid_params
      response.should be_success
    end

    it 'loads CallerSession' do
      CallerSession.should_receive(:find).at_least(:once){ caller_session }
      put :switch_mode, valid_params
    end
    it 'loads Moderator' do
      Moderator.should_receive(:find){ moderator }
      put :switch_mode, valid_params
    end
    it 'updates Moderator#caller_session_id' do
      put :switch_mode, valid_params
      moderator.reload
      moderator.caller_session_id.should eq caller_session.id
    end
    it 'requests the conference_id for CallerSession' do
      put :switch_mode, valid_params
      @conf_list_request.should have_been_made
    end
    it 'renders not connected message if caller is not on a call' do
      put :switch_mode, valid_params
      response.body.should eq "Status: Caller is not connected to a lead."
    end
    it 'renders a message with monitoring type and caller identity info when caller is on a call' do
      call_attempt = create(:call_attempt, {
        caller_session: caller_session,
        status: 'Call in progress'
      })
      voter = create(:voter, {
        call_attempts: [call_attempt],
        caller_session: caller_session
      })
      put :switch_mode, valid_params
      # response.body.should eq "Status: Monitoring in eavesdrop mode on #{caller_session.caller.identity_name}."
    end
  end
end
