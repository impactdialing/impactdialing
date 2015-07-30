require 'rails_helper'

describe Twiml::LeadController do
  after do
    Redis.new.flushall
  end

  describe '#answered' do
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
    let(:rest_response) do
      HashWithIndifferentAccess.new({
        'status'      => 'in-progress',
        'sid'         => 'CA123',
        'account_sid' => 'AC432'
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

      it 'loads @caller_session' do
        post :answered, twilio_params
        expect(assigns[:caller_session]).to eq caller_session
      end

      it 'tells @campaign :number_not_ringing' do
        expect(campaign).to receive(:number_not_ringing)
        allow(Campaign).to receive(:find){ campaign }
        post :answered, twilio_params
      end

      it 'tells @dialed_call :answered, passing campaign, caller_session & params' do
        dialed_call = double('CallFlow::Call::Dialed', {caller_session_sid: caller_session.sid})
        expect(dialed_call).to receive(:answered).with(campaign, caller_session, twilio_params.merge(action: 'answered', controller: 'twiml/lead'))
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

