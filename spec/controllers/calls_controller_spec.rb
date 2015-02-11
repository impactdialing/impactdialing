require "spec_helper"

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
        it 'is decremented if :incoming was not visited'
        it 'is decremented if call status is no-answer'
        it 'is decremented if call status is busy'
        it 'is NOT decremented if call status is failed'
        it 'is decremented if call answered by machine and AMD set to Hangup'
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