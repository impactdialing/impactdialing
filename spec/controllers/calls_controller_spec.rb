require 'rails_helper'

describe CallsController, :type => :controller do
  let(:recording){ create(:recording) }
  let(:campaign){ create(:power, {recording: recording}) }
  let(:caller){ create(:caller, {campaign: campaign}) }
  let(:caller_session){ create(:webui_caller_session, {caller: caller}) }
  let(:voter){ create(:voter, {campaign: campaign}) }
  let(:call_attempt){ create(:call_attempt, {voter: voter, campaign: campaign, caller_session: caller_session}) }
  let(:call){ create(:call, {call_attempt: call_attempt}) }

  describe 'TwiML endpoints' do
    describe '#incoming' do
      after do
        Redis.new.flushall
      end
      it 'uses CallFlow::Call to record that :incoming was visited' do
        caller                      = create(:caller)
        call                        = create(:call, answered_by: "human", state: 'initial', call_status: "completed")
        caller_session              = create(:webui_caller_session, {caller: caller})
        call_attempt                = call.call_attempt
        call_attempt.caller_session = caller_session
        call_attempt.caller         = caller
        call_attempt.save!
        
        incoming_params = {
          'CallStatus' => 'in-progress',
          'id'         => call.id,
          'CallSid'    => 'CA123',
          'AccountSid' => 'AC432'
        }

        post :incoming, incoming_params

        live_call = CallFlow::Call.new(incoming_params)
        expect(live_call.state_visited?(:incoming)).to be_truthy
      end
    end
    describe "#call_ended" do
      context 'ringing count' do
        after do
          Redis.new.flushall
        end
        it 'is decremented if :incoming was not visited' do
          caller                      = create(:caller, campaign: campaign)
          call                        = create(:call, answered_by: "human", state: 'initial', call_status: "completed")
          caller_session              = create(:webui_caller_session, {caller: caller})
          call_attempt                = call.call_attempt
          call_attempt.campaign       = campaign
          call_attempt.caller_session = caller_session
          call_attempt.caller         = caller
          call_attempt.save!
          campaign.number_ringing

          expect(campaign.ringing_count).to eq 1
          
          incoming_params = {
            'CallStatus' => 'failed',
            'id'         => call.id,
            'CallSid'    => 'CA123',
            'AccountSid' => 'AC432'
          }

          post :call_ended, incoming_params

          expect(campaign.ringing_count).to eq 0
        end
      end
    end

    describe '#play_message' do
      before do
        allow(call).to receive(:enqueue_call_flow).with(CallerPusherJob, [caller_session.id, 'publish_message_drop_success'])
        allow(call).to receive(:enqueue_call_flow).with(Providers::Phone::Jobs::DropMessageRecorder, [call.id, 1])
        allow(Call).to receive(:find){ call }
      end

      it 'updates recording info on the associated CallAttempt' do
        expect(call).to receive(:enqueue_call_flow).with(Providers::Phone::Jobs::DropMessageRecorder, [call.id, 1]).once
        post :play_message, id: call.id
      end

      it 'sends a message_drop_success event via Pusher' do
        expect(call).to receive(:enqueue_call_flow).with(CallerPusherJob, [caller_session.id, 'publish_message_drop_success']).once
        post :play_message, id: call.id
      end

      it 'renders TwiML to play the associated recording' do
        allow(recording.file).to receive(:url){ '/oolala.jive' }
        post :play_message, id: call.id
        expect(response.body).to match(/#{recording.file.url}/)
      end
    end


    describe "#disconnected"  do
      before(:each) do
        @script         = create(:script)
        @caller         = create(:caller)
        @campaign       = create(:bare_power, script: @script, account: @caller.account)
        @caller_session = create(:caller_session, caller: @caller)
        @voter          = create(:voter, campaign: @campaign, caller_session: @caller_session)
        @call_attempt   = create(:call_attempt, voter: @voter, campaign: @campaign, caller_session: @caller_session, caller: @caller)
      end

      it "should hangup twiml" do
        call = create(:call, answered_by: "human", call_attempt: @call_attempt, state: 'connected')
        allow(call).to receive(:call_attempt){ @call_attempt }
        allow(Call).to receive(:find).with("#{call.id}"){ call }

        expect(RedisCallFlow).to receive(:push_to_disconnected_call_list).with(call.id, call.recording_duration, call.recording_url, @caller.id)
        expect(@call_attempt).to receive(:enqueue_call_flow).with(CallerPusherJob, [@caller_session.id, "publish_voter_disconnected"])

        post :disconnected, call.attributes
        
        expect(response.body).to eq(Twilio::TwiML::Response.new { |r| r.Hangup }.text)
      end
    end
  end

  describe 'Browser endpoints' do
    describe '#drop_message' do
      it 'begins the drop message process' do
        allow(Call).to receive(:find){ call }
        expect(call).to receive(:enqueue_call_flow).with(Providers::Phone::Jobs::DropMessage, [call.id])
        post :drop_message, id: call.id
      end
    end
  end
end