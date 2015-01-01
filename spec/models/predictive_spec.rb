require "spec_helper"

describe Predictive do
  def attach_simulated_values(campaign, simulated_values)
    campaign.simulated_values = simulated_values
    campaign.save!
  end

  let(:account){ create(:account) }
  let(:campaign) do
    create(:predictive, {
      account: account,
      caller_id: Forgery(:address).phone[2..-1],
      recycle_rate: 3,
      acceptable_abandon_rate: 0.02
    })
  end

  before do
    Redis.new.flushall
  end

  describe 'abort_available_callers_with(twilio_redirect)' do
    before do
      allow(Providers::Phone::Call).to receive(:redirect_for)
      create_list(:bare_caller_session, 3, :available, :webui, {campaign: campaign})
    end
    it 'updates each available session so available_for_call is false' do
      twilio_redirect = :account_has_no_funds
      
      campaign.abort_available_callers_with(twilio_redirect)
      actual = CallerSession.all.map(&:available_for_call)
      expect(actual.uniq).to eq [false]
    end

    it 'redirects each available session to twilio_redirect' do
      twilio_redirect = :time_period_exceeded

      campaign.caller_sessions.each do |cs|
        expect(Providers::Phone::Call).to receive(:redirect_for).with(cs, twilio_redirect)
      end
      campaign.abort_available_callers_with(twilio_redirect)
    end
  end

  describe '#numbers_to_dial' do
    include FakeCallData

    before do
      allow(campaign).to receive(:numbers_to_dial_count){ 1 }
    end

    context 'numbers_to_dial_count is zero' do
      before do
        allow(campaign).to receive(:numbers_to_dial_count){ 0 }
      end

      it 'returns an empty array' do
        actual = campaign.numbers_to_dial
        expect(actual).to eq []
      end

      it 'returns immediately' do
        expect(campaign).to_not receive(:account){ account }
        campaign.numbers_to_dial
      end
    end

    context 'numbers_to_dial_count > zero' do
      it "returns set of numbers" do
        voter         = add_voters(campaign, :voter, 1).first
        phone_numbers = campaign.numbers_to_dial
        expect(phone_numbers).to eq([voter.household.phone])
      end
    end
  end

  describe '#numbers_to_dial_count' do
    context 'no caller sessions available' do
      context 'no ringing/presented calls' do
        it 'returns 0' do
          expect(campaign.numbers_to_dial_count).to be_zero
        end
      end

      context 'ringing calls' do
        it 'returns < 0' do
          campaign.number_presented(1)
          campaign.number_ringing
          expect(campaign.numbers_to_dial_count).to be < 0
        end
      end

      context 'presented calls' do
        it 'returns < 0' do
          campaign.number_presented(1)
          expect(campaign.numbers_to_dial_count).to be < 0
        end
      end
    end

    context 'caller sessions available' do
      before do
        create_list(:bare_caller_session, 3, :webui, :available, {campaign: campaign})
        create_list(:bare_caller_session, 7, :webui, :not_available, {campaign: campaign})
      end
      context 'w/ dial factor not using simulated values' do
        context 'no ringing/presented/recent calls' do
          it 'returns number of available callers' do
            expect(campaign.numbers_to_dial_count).to eq campaign.caller_sessions.available.count
          end
        end
        context 'ringing calls' do
          it 'returns number of available callers sans number of ringing lines' do
            campaign.number_presented(1)
            campaign.number_ringing
            expect(campaign.numbers_to_dial_count).to eq(campaign.caller_sessions.available.count - 1)
          end
        end
        context 'presented households' do
          it 'returns number of available callers sans number of presented households' do
            campaign.number_presented(1)
            expect(campaign.numbers_to_dial_count).to eq(campaign.caller_sessions.available.count - 1)
          end
        end
      end

      context 'w/ dial factor using simulated values & acceptable abandon rate' do
        let(:best_dials){ 1.8 }
        before do
          create(:bare_call_attempt, :completed, {campaign: campaign})
          simulated_values = SimulatedValues.create(best_dials: best_dials, best_conversation: 0, longest_conversation: 0)
          attach_simulated_values(campaign, simulated_values)
        end
        context 'no ringing/presented calls' do
          it 'returns number of available callers * dial factor' do
            expect(campaign.numbers_to_dial_count).to eq(campaign.caller_sessions.available.count * best_dials.ceil)
          end
        end
        context 'ringing lines for all available callers' do
          it 'returns 0' do
            n = campaign.caller_sessions.available.count * best_dials.ceil
            campaign.number_presented(n)
            n.times{ campaign.number_ringing }
            expect(campaign.numbers_to_dial_count).to be_zero
          end
        end
        context 'households presented for all available callers' do
          it 'returns 0' do
            campaign.number_presented(campaign.caller_sessions.available.count * best_dials.ceil)
            expect(campaign.numbers_to_dial_count).to be_zero
          end
        end
      end

      it "returns (best_dials * available_callers_count) - ringing - presented, when a call attempt has been created in last 10 minutes" do
        simulated_values = SimulatedValues.create(best_dials: 2.33345, best_conversation: 34.0076, longest_conversation: 42.0876, best_wrapup_time: 10.076)
        attach_simulated_values(campaign, simulated_values)

        create_list(:bare_call_attempt, 25, :completed, call_start: 40.seconds.ago, wrapup_time: 5.seconds.ago, campaign: campaign)

        campaign.number_presented(3)
        2.times{ campaign.number_ringing }

        # 3 available callers * 3 best dials - 2 ringing lines - 1 presented line
        expect(campaign.numbers_to_dial_count).to eq((3 * 3) - 2 - 1)
      end

      it "returns number of available callers when no call attempts created in last 10 minutes" do
        simulated_values = SimulatedValues.create(best_dials: 1, best_conversation: 0, longest_conversation: 0)
        attach_simulated_values(campaign, simulated_values)

        expect(campaign.numbers_to_dial_count).to eq(campaign.caller_sessions.available.count)
      end

      it "returns number of available callers when no simulated dials exist" do
        expect(campaign.numbers_to_dial_count).to eq(campaign.caller_sessions.available.count)
      end
    end
  end

  describe "best dials simulated" do
    it "should return 1 as best dials if simulated_values is nil" do
      expect(campaign.best_dials_simulated).to eq(1)
    end

    it "should return 1 as best dials if  best_dials simulated_values is nil" do
      expect(campaign.best_dials_simulated).to eq(1)
    end

    it "should return best dials  if  best_dials simulated_values is has a value" do
      simulated_values = SimulatedValues.create(best_dials: 1.8, best_conversation: 0, longest_conversation: 0)
      attach_simulated_values(campaign, simulated_values)

      expect(campaign.best_dials_simulated).to eq(2)
    end

    it "should return `TwilioLimit.get` if best_dials simulated_values is greater than `TwilioLimit.get`" do
      simulated_values = SimulatedValues.create(best_dials: 10.0, best_conversation: 0, longest_conversation: 0)
      attach_simulated_values(campaign, simulated_values)

      expect(campaign.best_dials_simulated).to eq(TwilioLimit.get)
    end
  end

  describe "best conversations simulated" do
    it "should return 0 as best conversation if simulated_values is nil" do
      expect(campaign.best_conversation_simulated).to eq(1000)
    end

    it "should return 0 as best conversation if best_conversation simulated_values is nil" do
      expect(campaign.best_conversation_simulated).to eq(1000)
    end

    it "should return best conversation if  best_conversation simulated_values is has a value" do
      simulated_values = SimulatedValues.create(best_dials: 1.8, best_conversation: 34.34, longest_conversation: 0)
      attach_simulated_values(campaign, simulated_values)

      expect(campaign.best_conversation_simulated).to eq(34.34)
    end
  end

  describe "longest conversations simulated" do
    it "should return 0 as longest conversation if simulated_values is nil" do
      expect(campaign.longest_conversation_simulated).to eq(1000)
    end

    it "should return 0 as longest conversation if longest_conversation simulated_values is nil" do
      expect(campaign.longest_conversation_simulated).to eq(1000)
    end

    it "should return longest conversation if  longest_conversation simulated_values is has a value" do
      simulated_values = SimulatedValues.create(best_dials: 1.8, best_conversation: 34.34, longest_conversation: 67.09)
      attach_simulated_values(campaign, simulated_values)

      expect(campaign.longest_conversation_simulated).to eq(67.09)
    end
  end

  describe "abandon rate acceptable" do
    it "should return false if  not acceptable" do
      campaign.update_attributes(acceptable_abandon_rate: 0.03)
      10.times { create(:call_attempt, campaign: campaign, :call_start => 40.seconds.ago, call_end: 10.seconds.ago, :wrapup_time => 5.seconds.ago, status: CallAttempt::Status::SUCCESS) }
      10.times { create(:call_attempt, campaign: campaign, :call_start => 40.seconds.ago, call_end: 10.seconds.ago, :wrapup_time => 5.seconds.ago, status: CallAttempt::Status::ABANDONED) }

      expect(campaign.abandon_rate_acceptable?).to be_falsey
    end
    it "should return true if  acceptable" do
      campaign.update_attributes(acceptable_abandon_rate: 0.03)
      40.times { create(:call_attempt, campaign: campaign, :call_start => 40.seconds.ago, call_end: 10.seconds.ago, :wrapup_time => 5.seconds.ago, status: CallAttempt::Status::SUCCESS) }
      1.times { create(:call_attempt, campaign: campaign, :call_start => 40.seconds.ago, call_end: 10.seconds.ago, :wrapup_time => 5.seconds.ago, status: CallAttempt::Status::ABANDONED) }

      expect(campaign.abandon_rate_acceptable?).to be_truthy
    end

    it "should only consider answered calls for abandonment rate" do
      campaign.update_attributes(acceptable_abandon_rate: 0.01)
      9.times { create(:call_attempt, campaign: campaign, :call_start => 40.seconds.ago, call_end: 10.seconds.ago, :wrapup_time => 5.seconds.ago, status: CallAttempt::Status::SUCCESS) }
      2.times { create(:call_attempt, campaign: campaign, :call_start => 40.seconds.ago, call_end: 10.seconds.ago, :wrapup_time => 5.seconds.ago, status: CallAttempt::Status::BUSY) }
      1.times { create(:call_attempt, campaign: campaign, :call_start => 40.seconds.ago, call_end: 10.seconds.ago, :wrapup_time => 5.seconds.ago, status: CallAttempt::Status::ABANDONED) }

      expect(campaign.abandon_rate_acceptable?).to be_falsey
    end
  end
end

# ## Schema Information
#
# Table name: `campaigns`
#
# ### Columns
#
# Name                                      | Type               | Attributes
# ----------------------------------------- | ------------------ | ---------------------------
# **`id`**                                  | `integer`          | `not null, primary key`
# **`campaign_id`**                         | `string(255)`      |
# **`name`**                                | `string(255)`      |
# **`account_id`**                          | `integer`          |
# **`script_id`**                           | `integer`          |
# **`active`**                              | `boolean`          | `default(TRUE)`
# **`created_at`**                          | `datetime`         |
# **`updated_at`**                          | `datetime`         |
# **`caller_id`**                           | `string(255)`      |
# **`type`**                                | `string(255)`      |
# **`recording_id`**                        | `integer`          |
# **`use_recordings`**                      | `boolean`          | `default(FALSE)`
# **`calls_in_progress`**                   | `boolean`          | `default(FALSE)`
# **`recycle_rate`**                        | `integer`          | `default(1)`
# **`answering_machine_detect`**            | `boolean`          |
# **`start_time`**                          | `time`             |
# **`end_time`**                            | `time`             |
# **`time_zone`**                           | `string(255)`      |
# **`acceptable_abandon_rate`**             | `float`            |
# **`call_back_after_voicemail_delivery`**  | `boolean`          | `default(FALSE)`
# **`caller_can_drop_message_manually`**    | `boolean`          | `default(FALSE)`
# **`households_count`**                    | `integer`          | `default(0)`
#
