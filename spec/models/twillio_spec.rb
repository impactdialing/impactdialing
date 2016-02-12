require 'rails_helper'

describe Twillio do
  include FakeCallData
  
  let(:account){ create(:account) }

  shared_examples 'all success Twillio.dials' do
    it 'creates a CallFlow::Call::Dialed (redis) record' do
      expect(dialed_call.sid).to eq call_sid
      expect(dialed_call.account_sid).to eq account_sid
      expect(dialed_call.storage['status']).to eq call_status
    end

    it 'adds 1 to campaign.ringing_count' do
      expect(campaign.ringing_count).to eq 1
    end
  end

  shared_examples 'Predictive failed Twillio.dials' do
    it 'subtracts 1 from campaign.presented_count' do
      expect(campaign.presented_count).to eq 0
    end
  end

  shared_examples 'all failed Twillio.dials' do
    it 'adds phone to completed:failed zset' do
      expect(phone).to be_in_dial_queue_zset campaign.id, 'failed'
    end

    it 'removes phone from available:presented zset' do
      expect(phone).to_not be_in_dial_queue_zset campaign.id, 'presented'
    end

    it 'queues CallFlow::Jobs::Persistence' do
      expect([:sidekiq, :persistence]).to have_queued(CallFlow::Jobs::Persistence).with('Failed', campaign.id, phone)
    end
  end

  shared_context 'Twillio setup' do
    let(:caller) do
      create(:caller, campaign: campaign, account: account)
    end
    let(:caller_session) do
      create(:bare_caller_session, :webui, :available, campaign: campaign, caller: caller, sid: 'caller-session-sid')
    end
    let(:phone){ twilio_valid_to }
  end

  shared_context 'dialed call' do
    let(:account_sid){ @twilio_response['account_sid'] }
    let(:call_sid){ @twilio_response['sid'] }
    let(:call_status){ 'queued' }
    let(:dialed_call) do
      CallFlow::Call::Dialed.new(account_sid, call_sid)
    end
  end

  describe 'Twillio.dial (Preview/Power)' do
    let(:campaign) do
      create_campaign_with_script(:bare_preview, account).last
    end

    include_context 'Twillio setup'
    include_context 'dialed call'

    context 'success' do
      before do
        caller_session.update_attributes!({sid: 'CS123'})
        VCR.use_cassette('Twillio.dial success') do
          @twilio_response = Twillio.dial(phone, caller_session)
        end
      end

      it_behaves_like 'all success Twillio.dials' 

      it 'updates CallerSession w/ attempt in progress & available for call flags' do
        expect(caller_session.on_call).to be_truthy
        expect(caller_session.available_for_call).to be_falsey
        expect(dialed_call.storage['caller_session_sid']).to eq caller_session.sid
      end
    end

    context 'fail' do
      let(:phone){ twilio_invalid_to[1..-1] } # strip leading '+'

      before do
        presented_key = campaign.dial_queue.available.send(:keys)[:presented]
        redis.zadd presented_key, 3.2, phone

        VCR.use_cassette('Twillio.dial fail-invalid to') do
          Twillio.dial(twilio_invalid_to, caller_session)
        end
      end

      it_behaves_like 'all failed Twillio.dials'

      it 'redirects caller' do
        expect(Providers::Phone::Call).to receive(:redirect_for).with(caller_session)
        VCR.use_cassette('Twillio.dial fail-invalid to') do
          Twillio.dial(twilio_invalid_to, caller_session)
        end
      end
    end
  end

  describe 'Twillio.dial_predictive_em (Predictive)' do
    require "em-synchrony/em-http"
    require "em-synchrony/fiber_iterator"

    def dial_em(phones, concurrency=1)
      EM.synchrony do
        EM::Synchrony::FiberIterator.new(phones, concurrency).each do |phone,iter|
          @twilio_response = Twillio.dial_predictive_em(iter, campaign, phone)
        end
        EventMachine.stop
      end
    end

    let(:campaign) do
      create_campaign_with_script(:bare_predictive, account).last
    end

    let(:account_sid){ @twilio_response['account_sid'] }
    let(:call_sid){ @twilio_response['sid'] }
    let(:call_status){ 'queued' }
    let(:dialed_call) do
      CallFlow::Call::Dialed.new(account_sid, call_sid)
    end

    include_context 'Twillio setup'
    #include_context 'dialed call'

    context 'success' do
      before do
        campaign.number_presented(1)
        VCR.use_cassette('Twillio.dial_predictive_em success') do
          dial_em([phone])
        end
      end

      it_behaves_like 'all success Twillio.dials'
      it 'subtracts 1 from campaign.presented_count' do
        expect(campaign.presented_count).to eq 0
      end
    end

    context 'fail' do
      let(:phone){ twilio_invalid_to[1..-1] } # strip leading '+'

      before do
        # todo: move this from before block to it
        expect(Providers::Phone::Call).to_not receive(:redirect_for).with(caller_session)

        presented_key = campaign.dial_queue.available.send(:keys)[:presented]
        redis.zadd presented_key, 3.2, phone
        campaign.number_presented(1)

        VCR.use_cassette('Twillio.dial_predictive_em fail') do
          dial_em([twilio_invalid_to])
        end
      end

      it_behaves_like 'all failed Twillio.dials'
      it_behaves_like 'Predictive failed Twillio.dials'

      it 'does not redirect caller' do
        # todo: move expectation in before block to here
      end

      context 'An empty response is returned from HTTP request' do
        before do
          campaign.number_presented(1)
          Twillio.handle_response('', campaign, twilio_invalid_to)
        end

        it_behaves_like 'all failed Twillio.dials'
        it_behaves_like 'Predictive failed Twillio.dials'
        
        it 'does not raise JSON::ParseError' do
          expect{
            Twillio.handle_response('', campaign, twilio_invalid_to)
          }.not_to raise_error
        end
      end
    end
  end
end
