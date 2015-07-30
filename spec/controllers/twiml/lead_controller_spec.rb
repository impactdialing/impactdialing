require 'rails_helper'

describe Twiml::LeadController do
  after do
    Redis.new.flushall
  end

  let(:twilio_params) do
    HashWithIndifferentAccess.new({
      'CallStatus'    => 'in-progress',
      'CallSid'       => 'CA123',
      'AccountSid'    => 'AC432',
      'campaign_id'   => campaign.id,
      'campaign_type' => campaign.type,
      'format'        => 'xml'
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

  describe '#completed' do
  end

  describe '#disconnected' do
    let(:campaign){ create(:predictive) }
    let(:disconnected_params) do
      twilio_params.merge(HashWithIndifferentAccess.new({
        'From' => '5551235839',
        'To' => '+13829583828'
      }))
    end

    it 'tells @dialed_call :disconnected' do
      dialed_call = double('CallFlow::Call::Dialed', {disconnected: nil})
      expect(dialed_call).to receive(:disconnected).with(disconnected_params.merge({
        'action' => 'disconnected',
        'controller' => 'twiml/lead'
      }))
      allow(CallFlow::Call::Dialed).to receive(:new){ dialed_call }
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

    shared_examples_for 'answered call of any dialing mode' do
      it 'loads @dialed_call' do
        post :answered, twilio_params
        expect(assigns[:dialed_call]).to be_kind_of CallFlow::Call::Dialed
      end

      it 'loads @campaign' do
        post :answered, twilio_params
        expect(assigns[:campaign]).to eq campaign
      end

      it 'tells @campaign :number_not_ringing' do
        expect(campaign).to receive(:number_not_ringing)
        allow(Campaign).to receive(:find){ campaign }
        post :answered, twilio_params
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
    end

    context 'Power dial mode' do
      let(:campaign){ create(:power) }
      before do
        CallFlow::Call::Dialed.create(campaign, rest_response, {caller_session_sid: caller_session.sid})
      end
      
      it_behaves_like 'answered call of any dialing mode'
    end

    context 'Predictive dial mode' do
      let(:campaign){ create(:predictive) }
      let(:dialed_call){ CallFlow::Call::Dialed.create(campaign, rest_response) }

      before do
        dialed_call.caller_session_sid = caller_session.sid
        RedisOnHoldCaller.add(campaign.id, caller_session.id)
      end

      it_behaves_like 'answered call of any dialing mode'
    end
  end
end

