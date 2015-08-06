require 'rails_helper'

describe Twillio do
  include FakeCallData
  
  let(:account){ create(:account) }
  let(:redis){ Redis.new }

  before do
    Redis.new.flushall

    silence_warnings{
      TWILIO_ACCOUNT                = 'AC211da899fe0c76480ff2fc4ad2bbdc79'
      TWILIO_AUTH                   = '09e459bfca8da9baeead9f9537735bbf'
      ENV['TWILIO_CALLBACK_HOST']   = 'api.twilio.com'
      ENV['CALL_END_CALLBACK_HOST'] = 'api.twilio.com'
      ENV['INCOMING_CALLBACK_HOST'] = 'api.twilio.com'
      ENV['VOIP_API_URL']           = 'api.twilio.com'
    }
  end

  after do
    silence_warnings{
      TWILIO_ACCOUNT                = "blahblahblah"
      TWILIO_AUTH                   = "blahblahblah"
      ENV['TWILIO_CALLBACK_HOST']   = 'test.com'
      ENV['CALL_END_CALLBACK_HOST'] = 'test.com'
      ENV['INCOMING_CALLBACK_HOST'] = 'test.com'
      ENV['VOIP_API_URL']           = 'test.com'
    }
  end

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

  shared_examples 'Predictive success Twillio.dials' do
  end

  shared_examples 'Predictive failed Twillio.dials' do
    it 'subtracts 1 from campaign.presented_count' do
      expect(campaign.presented_count).to eq 0
    end
  end

  shared_examples 'all failed Twillio.dials' do
    it 'updates CallAttempt status to FAILED' do
      expect(CallAttempt.last.status).to eq CallAttempt::Status::FAILED
    end

    it 'updates CallAttempt wrapup_time' do
      expect(CallAttempt.last.wrapup_time).to be > 1.minute.ago
    end

    it 'updates Household status to FAILED' do
      expect(household.reload.status).to eq CallAttempt::Status::FAILED
    end
  end

  shared_context 'Twillio setup' do
    let(:caller) do
      create(:caller, campaign: campaign, account: account)
    end
    let(:caller_session) do
      create(:bare_caller_session, :webui, :available, campaign: campaign, caller: caller)
    end
    let(:phone){ '15418703001' }
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
      let(:fake_dial_queue) do
        double('CallFlow::DialQueue', {
          failed!: nil
        })
      end
      before do
        allow(CallFlow::DialQueue).to receive(:new).with(campaign){ fake_dial_queue }
      end

      after do
        VCR.use_cassette('Twillio.dial fail-invalid to') do
          Twillio.dial(twilio_invalid_to, caller_session)
        end
      end

      it 'calls campaign.dial_queue.failed!' do
        expect(fake_dial_queue).to receive(:failed!).with(twilio_invalid_to)
      end

      it 'redirects caller' do
        expect(Providers::Phone::Call).to receive(:redirect_for).with(caller_session)
      end
    end
  end

  describe 'Twillio.dial_predictive_em (Predictive)' do
    let(:campaign) do
      create_campaign_with_script(:bare_predictive, account).last
    end

    let(:account_sid){ 'AC0987654321' }
    let(:call_sid){ 'CA1234567890' }
    let(:call_status){ 'queued' }
    let(:dialed_call) do
      CallFlow::Call::Dialed.new(account_sid, call_sid)
    end

    # ugh; todo: figure out how to hook vcr up w/ eventmachine
    class EmHttpFake
      def callback(&block)
        yield
      end
      def errback(&block)
      end
      def response
        {
          status: 200,
          sid: 'CA1234567890',
          account_sid: 'AC0987654321'
        }.to_json
      end
    end

    include_context 'Twillio setup'
    #include_context 'dialed call'

    context 'success' do
      before do
        campaign.number_presented(1)

        #twilio_lib = double('TwilioLib instance', {
        #  make_call_em: EmHttpFake.new
        #})
        #iterator = double('EmHttpIterator', {return: nil})
        #allow(TwilioLib).to receive(:new){ twilio_lib }
        require "em-synchrony/fiber_iterator"
        VCR.use_cassette('Twillio.dial_predictive_em success') do
          EM.synchrony do
            EM::Synchrony::FiberIterator.new([phone], 1).map do |phone,iter|
              Twillio.dial_predictive_em(iter, campaign, phone)
            end
            EventMachine.stop
          end
        end
      end

      it_behaves_like 'all success Twillio.dials'
      it 'subtracts 1 from campaign.presented_count and ' do
        expect(campaign.presented_count).to eq 0
      end
    end

    context 'fail' do

      class EmHttpFakeFail < EmHttpFake
        def callback(&block)
        end
        def errback(&block)
          yield
        end
        def response
          {
            status: 400
          }.to_json
        end
      end
      before do
        # todo: move this from before block to it
        expect(Providers::Phone::Call).to_not receive(:redirect_for).with(caller_session)

        campaign.number_presented(1)

        twilio_lib = double('TwilioLib instance', {
          make_call_em: EmHttpFakeFail.new
        })
        iterator = double('EmHttpIterator', {return: nil})
        allow(TwilioLib).to receive(:new){ twilio_lib }

        household.update_attributes!(phone: twilio_invalid_to)
        @twilio_response = Twillio.dial_predictive_em(iterator, household)
      end

      it_behaves_like 'all failed Twillio.dials'
      it_behaves_like 'Predictive failed Twillio.dials'

      it 'does not redirect caller' do
        # todo: move expectation in before block to here
      end

      context 'An empty response is returned from HTTP request' do
        class EmHttpFakeFail < EmHttpFake
          def response
            ''
          end
        end

        let(:iterator){ double('EmHttpIterator', {return: nil}) }

        before do
          campaign.number_presented(1)

          twilio_lib = double('TwilioLib instance', {
            make_call_em: EmHttpFakeFail.new
          })
          allow(TwilioLib).to receive(:new){ twilio_lib }

          household.update_attributes!(phone: twilio_invalid_to)
          Twillio.dial_predictive_em(iterator, household)
        end

        it_behaves_like 'all failed Twillio.dials'
        it_behaves_like 'Predictive failed Twillio.dials'
        
        it 'does not raise JSON::ParseError' do
          expect{
            Twillio.dial_predictive_em(iterator, household)
          }.not_to raise_error
        end
      end
    end
  end
end
