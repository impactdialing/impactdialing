require 'spec_helper'

describe Twillio do
  include FakeCallData
  
  let(:account){ create(:account) }

  before do
    Redis.new.flushall

    TWILIO_ACCOUNT                = 'AC211da899fe0c76480ff2fc4ad2bbdc79'
    TWILIO_AUTH                   = '09e459bfca8da9baeead9f9537735bbf'
    ENV['TWILIO_CALLBACK_HOST']   = 'api.twilio.com'
    ENV['CALL_END_CALLBACK_HOST'] = 'api.twilio.com'
    ENV['INCOMING_CALLBACK_HOST'] = 'api.twilio.com'
    ENV['VOIP_API_URL']           = 'api.twilio.com'
  end

  shared_examples 'all Twillio.dials' do
    it 'create CallAttempt record associated to target household & campaign' do
      call_attempt = CallAttempt.last
      
      expect(call_attempt).to be_present
      expect(household.call_attempts.last).to eq call_attempt
      expect(campaign.call_attempts.last).to eq call_attempt
    end

    it 'create Call record associated to CallAttempt' do
      call = Call.last

      expect(call).to be_present
      expect(call.call_attempt).to eq CallAttempt.last
    end
  end

  shared_examples 'all success Twillio.dials' do
    it 'updates CallAttempt w/ SID from response to make call' do
      call_attempt = CallAttempt.last
      expect(call_attempt.sid).to be_present
      expect(call_attempt.sid).to be =~ /CA.*/
    end

    it 'subtracts 1 from campaign.presented_count and adds 1 to campaign.ringing_count' do
      expect(campaign.presented_count).to eq 0
      expect(campaign.ringing_count).to eq 1
    end
  end

  shared_examples 'all failed Twillio.dials' do
    it 'subtracts 1 from campaign.presented_count' do
      expect(campaign.presented_count).to eq 0
    end

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
    let(:household) do
      create(:household, phone: '15418703001', campaign: campaign, account: campaign.account)
    end
  end

  describe 'Twillio.dial (Preview/Power)' do
    let(:campaign) do
      create_campaign_with_script(:bare_preview, account).last
    end

    include_context 'Twillio setup'

    context 'success' do
      before do
        campaign.number_presented(1)

        VCR.use_cassette('Twillio.dial success') do
          Twillio.dial(household, caller_session)
        end
      end

      it_behaves_like 'all Twillio.dials'
      it_behaves_like 'all success Twillio.dials'

      it 'updates CallerSession w/ attempt in progress & available for call flags' do
        expect(caller_session.on_call).to be_truthy
        expect(caller_session.available_for_call).to be_falsey
        expect(caller_session.attempt_in_progress).to be_present
        expect(caller_session.attempt_in_progress).to eq CallAttempt.last
      end
    end

    context 'fail' do
      before do
        # todo: move this from before block to it
        expect(Providers::Phone::Call).to receive(:redirect_for).with(caller_session)

        campaign.number_presented(1)
        household.update_attributes!(phone: twilio_invalid_to)

        VCR.use_cassette('Twillio.dial fail-invalid to') do
          Twillio.dial(household, caller_session)
        end
      end

      it_behaves_like 'all Twillio.dials'
      it_behaves_like 'all failed Twillio.dials'

      it 'redirects caller' do
        # todo: move expectation in before block to here
      end
    end
  end

  describe 'Twillio.dial_predictive_em (Predictive)' do
    let(:campaign) do
      create_campaign_with_script(:bare_predictive, account).last
    end

    # ugh; todo: figure out how to hook vcr up w/ eventmachine
    class EmHttpFake
      def callback(&block)
        yield
      end
      def errback(&block)
        yield
      end
      def response
        {
          status: 200,
          sid: 'CA1234567890'
        }.to_json
      end
    end

    include_context 'Twillio setup'

    context 'success' do
      before do
        campaign.number_presented(1)

        twilio_lib = double('TwilioLib instance', {
          make_call_em: EmHttpFake.new
        })
        iterator = double('EmHttpIterator', {return: nil})
        allow(TwilioLib).to receive(:new){ twilio_lib }
        Twillio.dial_predictive_em(iterator, household)
      end

      it_behaves_like 'all Twillio.dials'
      it_behaves_like 'all success Twillio.dials'
    end

    context 'fail' do

      class EmHttpFakeFail < EmHttpFake
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
        Twillio.dial_predictive_em(iterator, household)
      end

      it_behaves_like 'all Twillio.dials'
      it_behaves_like 'all failed Twillio.dials'

      it 'does not redirect caller' do
        # todo: move expectation in before block to here
      end
    end
  end
end
