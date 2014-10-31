require 'spec_helper'
require 'app_health/monitor/recycle_rate_violations'

describe AppHealth::Monitor::RecycleRateViolations do
  let(:account){ create(:account) }
  let(:campaign){ create(:power, account: account) }
  let(:voter){ create(:realistic_voter, account: account, campaign: campaign) }

  def create_attempts(voter, time_a, time_b=Time.now)
    create(:bare_call_attempt, :machine_answered, voter: voter, created_at: time_a, campaign: campaign)
    create(:bare_call_attempt, :machine_answered, voter: voter, created_at: time_b, campaign: campaign) # created_at => Time.now by def
  end

  describe '.ok?' do
    it 'returns true if no call attempts with the same voter id have been created within an hour of each other' do
      expect( subject.ok? ).to be_truthy
    end

    describe 'alarm cases' do
      it '1st attempt 59 min ago; 2nd attempt just now' do
        create_attempts(voter, 59.minutes.ago)

        expect( subject.ok? ).to be_falsy
      end

      it '1st attempt 42 min ago; 2nd attempt 4 min ago' do
        create_attempts(voter, 42.minutes.ago, 4.minutes.ago)

        expect( subject.ok? ).to be_falsy
      end

      it '1st attempt 21 min ago; 2nd attempt 19 min ago' do
        create_attempts(voter, 21.minutes.ago, 19.minutes.ago)

        expect( subject.ok? ).to be_falsy
      end

      it '1st attempt 3 min ago; 2nd attempt now' do
        create_attempts(voter, 3.minutes.ago)

        expect( subject.ok? ).to be_falsy
      end
    end

    describe 'false positives' do
      it 'does not care that several different voters are called within an hour of each other' do
        voter2 = create(:realistic_voter, account: account, campaign: campaign)
        voter3 = create(:realistic_voter, account: account, campaign: campaign)
        create_attempts(voter, 71.minutes.ago)
        create_attempts(voter2, 71.minutes.ago)
        create_attempts(voter3, 71.minutes.ago)

        expect( subject.ok? ).to(be_truthy, "#{subject.class.inspect_violators.map{|r| r.join(', ')}.join(' -- ')}")
      end
    end
  end

  describe '.alert_if_not_ok' do
    let(:pager_duty_events_url){ "https://events.pagerduty.com/generic/2010-04-15/create_event.json" }

    context '.ok? => false' do
      before do
        create_attempts(voter, 45.minutes.ago)
      end
      it 'triggers a PagerDuty event, providing some info about the violators' do
        VCR.use_cassette('pagerduty recycle rate alert') do
          subject.alert_if_not_ok
          expect(WebMock).to have_requested(:post, pager_duty_events_url)
        end
      end

      context 'PagerDuty event fails to trigger' do
        context 'due to temporary network failure' do
          it 'retries connection timeouts'
        end
      end
    end

    context '.ok? => true' do
      it 'does nothing'
    end
  end
end
