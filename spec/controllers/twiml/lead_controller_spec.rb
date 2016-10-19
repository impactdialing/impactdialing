require 'rails_helper'

describe Twiml::LeadController do
  let(:twilio_params) do
    HashWithIndifferentAccess.new({
      'CallStatus'    => 'in-progress',
      'CallSid'       => 'CA123',
      'AccountSid'    => 'AC432',
      'campaign_id'   => campaign.id.to_s,
      'campaign_type' => campaign.type
    })
  end
  let(:caller_session) do
    create(:webui_caller_session, {
      campaign: campaign,
      sid: 'CA-caller-session-sid',
      on_call: true,
      available_for_call: false
    })
  end

  describe '#play_message' do
    let(:campaign){ create(:predictive) }
    let(:recording){ create(:recording, account: campaign.account) }
    let(:dialed_call){ CallFlow::Call::Dialed.new(twilio_params[:AccountSid], twilio_params[:CallSid]) }
    let(:params) do
      twilio_params
    end
    let(:action){ :play_message }
    let(:processed_response_template){ 'twiml/lead/play_message' }

    before do
      dialed_call.storage[:campaign_id] = campaign.id
      dialed_call.caller_session_sid = caller_session.sid
      campaign.update_attribute(:recording_id, recording.id)
    end

    it_behaves_like 'processable twilio fallback url requests'
    it_behaves_like 'unprocessable lead twilio fallback url requests'

    it 'tells @dialed_call :manual_message_dropped' do
      allow(CallFlow::Call::Dialed).to receive(:new){ dialed_call }
      expect(dialed_call).to receive(:manual_message_dropped).with(recording)
      post :play_message, twilio_params
    end

    it 'sets @recording to @campaign.recording' do
      post :play_message, twilio_params
      expect(assigns[:recording]).to eq recording
    end

    it 'renders twiml/lead/play_message.xml.erb' do
      post :play_message, twilio_params
      expect(response).to render_template 'twiml/lead/play_message'
    end
  end

  describe '#completed' do
    let(:campaign){ create(:predictive) }
    let(:status_callback_params) do
      twilio_params.merge(HashWithIndifferentAccess.new({
        'CallDuration'      => "120",
        'RecordingUrl'      => 'http://recordings.twilio.com/yep.mp3',
        'RecordingSid'      => 'RE-341',
        'RecordingDuration' => "119",
        'campaign_id'       => campaign.id.to_s
      }))
    end
    let(:dialed_call) do
      CallFlow::Call::Dialed.new(twilio_params['AccountSid'], twilio_params['CallSid'])
    end
    let(:params) do
      twilio_params
    end
    let(:action){ :completed }
    let(:processed_response_template){ '' }

    before do
      dialed_call.caller_session_sid = caller_session.sid
    end

    it_behaves_like 'processable twilio fallback url requests'
    it_behaves_like 'unprocessable lead twilio fallback url requests'

    it 'tells @dialed_call :completed' do
      dialed_call = double('CallFlow::Call::Dialed', {completed: nil})
      allow(CallFlow::Call::Dialed).to receive(:new).with(status_callback_params[:AccountSid], status_callback_params[:CallSid]){ dialed_call }
      expect(dialed_call).to receive(:completed).with(campaign, status_callback_params.merge({
        'action' => 'completed',
        'controller' => 'twiml/lead'
      }))
      post :completed, status_callback_params
    end

    it 'renders nothing (Twilio makes this request after the call has ended)' do
      post :completed, status_callback_params
      expect(response).to render_template nil
    end
  end

  describe '#disconnected' do
    let(:campaign){ create(:predictive) }
    let(:disconnected_params) do
      twilio_params.merge(HashWithIndifferentAccess.new({
        'From' => '5551235839',
        'To' => '+13829583828'
      }))
    end
    let(:dialed_call_storage) do
      instance_double('CallFlow::Call::Storage')
    end
    let(:dialed_call) do
      double('CallFlow::Call::Dialed', {storage: dialed_call_storage,disconnected: nil})
    end
    let(:params) do
      disconnected_params
    end
    let(:action){ :disconnected }
    let(:processed_response_template){ 'twiml/lead/disconnected' }

    before do
      allow(dialed_call).to receive(:storage){dialed_call_storage}
      allow(dialed_call_storage).to receive(:[]){campaign.id}
      allow(dialed_call).to receive(:disconnected).with(campaign, disconnected_params.merge({
        'action' => 'disconnected',
        'controller' => 'twiml/lead'
      }))
      allow(CallFlow::Call::Dialed).to receive(:new){ dialed_call }
    end

    it_behaves_like 'processable twilio fallback url requests'
    it_behaves_like 'unprocessable lead twilio fallback url requests'

    it 'tells @dialed_call :disconnected' do
      expect(dialed_call).to receive(:disconnected).with(campaign, disconnected_params.merge({
        'action' => 'disconnected',
        'controller' => 'twiml/lead'
      }))
      post :disconnected, disconnected_params
    end
  end

  describe '#answered' do
    let(:rest_response) do
      HashWithIndifferentAccess.new({
        'status'      => 'in-progress',
        'sid'         => 'CA123',
        'account_sid' => 'AC432'
      })
    end
    let(:twilio_callback_params) do
      {
        host: Settings.twilio_callback_host,
        port: Settings.twilio_callback_port,
        protocol: 'http://'
      }
    end
    let(:params) do
      twilio_params
    end
    let(:action){ :answered }
    let(:processed_response_template){ 'twiml/lead/answered' }

    shared_examples_for 'answered call of any dialing mode' do
      it 'loads @dialed_call' do
        post :answered, twilio_params
        expect(assigns[:dialed_call]).to be_kind_of CallFlow::Call::Dialed
      end

      it 'loads @campaign' do
        post :answered, twilio_params
        expect(assigns[:campaign]).to eq campaign
      end

      it 'tells @dialed_call :answered, passing campaign & params' do
        dialed_call = double('CallFlow::Call::Dialed', {caller_session: caller_session})
        expect(dialed_call).to receive(:answered).with(campaign, twilio_params.merge(action: 'answered', controller: 'twiml/lead'))
        allow(CallFlow::Call::Dialed).to receive(:new).with(twilio_params[:AccountSid], twilio_params[:CallSid]){ dialed_call }
        post :answered, twilio_params
      end

      it 'renders views/twiml/lead/answered.xml.erb' do
        post :answered, twilio_params
        expect(response).to render_template 'twiml/lead/answered'
      end
    end

    context 'Preview dial mode' do
      let(:campaign){ create(:preview) }
      before do
        CallFlow::Call::Dialed.create(campaign, rest_response, {caller_session_sid: caller_session.sid})
      end

      it_behaves_like 'answered call of any dialing mode'
      it_behaves_like 'processable twilio fallback url requests'
      it_behaves_like 'unprocessable lead twilio fallback url requests'
    end

    context 'Power dial mode' do
      let(:campaign){ create(:power) }
      before do
        CallFlow::Call::Dialed.create(campaign, rest_response, {caller_session_sid: caller_session.sid})
      end
      
      it_behaves_like 'answered call of any dialing mode'
      it_behaves_like 'processable twilio fallback url requests'
      it_behaves_like 'unprocessable lead twilio fallback url requests'
    end

    context 'Predictive dial mode' do
      let(:campaign){ create(:predictive) }
      let(:dialed_call){ CallFlow::Call::Dialed.create(campaign, rest_response) }

      before do
        dialed_call.caller_session_sid = caller_session.sid
        RedisOnHoldCaller.add(campaign.id, caller_session.id)
      end

      it_behaves_like 'answered call of any dialing mode'
      it_behaves_like 'processable twilio fallback url requests'
      it_behaves_like 'unprocessable lead twilio fallback url requests'
    end
  end
end

