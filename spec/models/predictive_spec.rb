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
    ENV['DIAL_QUEUE_AVAILABLE_LIMIT'] = '100'
  end

  describe 'check_campaign_fit_to_dial' do
    context 'campaign is fit to dial' do
      it 'returns true' do
        expect(campaign.check_campaign_fit_to_dial).to be_truthy
      end
    end

    context 'campaign is not fit to dial' do
      context 'aborting available callers' do
        before do
          expect(campaign).to receive(:abort_available_callers_with).with(:dialing_prohibited)
        end
        it 'account not funded' do
          campaign.account.quota.update_attributes!(minutes_allowed: 0)
          expect(campaign.check_campaign_fit_to_dial).to be_falsey
        end

        it 'outside calling hours' do
          campaign.update_attributes!(start_time: 3.hours.ago, end_time: 2.hours.ago)
          expect(campaign.check_campaign_fit_to_dial).to be_falsey
        end

        it 'calling disabled' do
          campaign.account.quota.update_attributes!(disable_calling: true)
          expect(campaign.check_campaign_fit_to_dial).to be_falsey
        end
      end
    end
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

  describe '#choose_voters_to_dial(num_voters)' do
    include FakeCallData
    
    def create_and_cache_voter(*args)
      voter = create(*args)
      cache_available_voters(campaign)
      voter
    end

    def create_and_cache_voter_list(*args)
      voters = create_list(*args)
      cache_available_voters(campaign)
      voters
    end

    context 'Given num_voters is zero or less' do
      it 'returns an empty array' do
        actual = campaign.choose_voters_to_dial(0)
        expect(actual).to eq []
      end

      it 'returns immediately' do
        expect(campaign).to_not receive(:account){ account }

        campaign.choose_voters_to_dial(0)
      end
    end

    it "load next voter to dial" do
      # voter = create(:realistic_voter, {campaign: campaign, account: account})
      voter = create_and_cache_voter(:realistic_voter, {campaign: campaign, account: account})

      expect(campaign.choose_voters_to_dial(1)).to eq([voter.id])
    end
    
    it 'marks voter(s) as READY before returning' do
      voter = create(:realistic_voter, {campaign: campaign})
      cache_available_voters(campaign)
      campaign.choose_voters_to_dial(20)
      expect(voter.reload.status).to eq CallAttempt::Status::READY
    end

    it 'does not load disabled (not enabled) voters' do
      # voter = create(:realistic_voter, :disabled, {campaign: campaign})
      voter = create_and_cache_voter(:realistic_voter, :disabled, {campaign: campaign})

      expect(campaign.choose_voters_to_dial(1)).to be_empty
    end

    it "dials enabled voters only" do
       # voter1 = create(:realistic_voter, campaign: campaign, enabled: true)
       voter1 = create_and_cache_voter(:realistic_voter, campaign: campaign)
       # voter2 = create(:realistic_voter, campaign: campaign, enabled: false)
       voter2 = create_and_cache_voter(:realistic_voter, :disabled, campaign: campaign)

       expect(campaign.choose_voters_to_dial(2)).to eq([voter1.id])
    end

    it "excludes system blocked numbers" do
      unblocked_voter                 = create(:realistic_voter, campaign: campaign, account: account)
      blocked_voter                   = create(:realistic_voter, :blocked, campaign: campaign, account: account)
      blocked_number                  = create(:blocked_number, number: blocked_voter.phone, account: account, campaign: nil)
      cache_available_voters(campaign)
      
      actual = campaign.choose_voters_to_dial(10)

      # binding.pry
      expect(actual).to_not include(blocked_voter.id)
      expect(actual).to include(unblocked_voter.id)
    end

    it "excludes campaign blocked numbers" do
      voter_list      = create(:voter_list, campaign: campaign, active: true)
      unblocked_voter = create(:realistic_voter, campaign: campaign, status: 'not called', voter_list: voter_list, account: account)
      blocked_voter   = create(:realistic_voter, :blocked, campaign: campaign, status: 'not called', voter_list: voter_list, account: account)
      blocked_number  = create(:blocked_number, number: blocked_voter.phone, account: account, campaign: campaign)
      cache_available_voters(campaign)

      actual = campaign.choose_voters_to_dial(10)

      # binding.pry
      expect(actual).to_not include(blocked_voter.id)
      expect(actual).to include(unblocked_voter.id)
    end

    it "always dials numbers that have not been dialed first" do
      create_list(:realistic_voter, 40, campaign: campaign, status: Voter::Status::NOTCALLED)
      dial_queue = cache_available_voters(campaign)

      voters = Voter.all
      dial_queue.next(5) # pretend caller skips these
      dial_queue.next(5) # and these are dialed
      voters[5..10].each{|v| v.update_attribute(:last_call_attempt_time, 30.minutes.ago)}

      dial_queue.next(5) # pretend caller skips these
      dial_queue.next(10) # and these are dialed
      voters[15..25].each{|v| v.update_attribute(:last_call_attempt_time, 30.minutes.ago)}

      dial_queue.next(10) # pretend caller skips these
      dial_queue.next(5) # and these are dialed
      voters[35..39].each{|v| v.update_attribute(:last_call_attempt_time, 30.minutes.ago)}

      cache_available_voters(campaign)

      actual = campaign.choose_voters_to_dial(20)
      # binding.pry
      [
       voters[0..4],
       voters[11..14],
       voters[26..34]
      ].flatten.map(&:id).each do |id|
        expect(actual).to include(id)
      end

      [
       voters[5..10],
       voters[15..25],
       voters[35..39]
      ].flatten.map(&:id).each do |id|
       expect(actual).not_to include(id)
      end
    end

    it "does not redial a voter that was called successfully" do
      voter = create(:realistic_voter, :success, :not_recently_dialed, {campaign: campaign})
      cache_available_voters(campaign)
      expect(campaign.choose_voters_to_dial(20)).not_to include(voter.id)
    end

    it "does not redial a voter that is in progress" do
      voter = create(:realistic_voter, :in_progress, {campaign: campaign})
      cache_available_voters(campaign)
      expect(campaign.choose_voters_to_dial(20)).not_to include(voter.id)
    end

    it "does not dial voter who has been just dialed recycle rate" do
      voter = create(:realistic_voter, campaign: campaign, status: CallAttempt::Status::BUSY, last_call_attempt_time: Time.now - 1.hour)
      cache_available_voters(campaign)
      create(:call_attempt, :voter => voter, status: CallAttempt::Status::BUSY)
      expect(campaign.choose_voters_to_dial(20)).not_to include(voter.id)
    end

    it "dials voter who has been dialed passed recycle rate" do
      voter = create(:realistic_voter, campaign: campaign, status: CallAttempt::Status::BUSY, last_call_attempt_time: Time.now - 4.hours)
      cache_available_voters(campaign)
      create(:call_attempt, :voter => voter, status: CallAttempt::Status::BUSY)
      expect(campaign.choose_voters_to_dial(20)).to include(voter.id)
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

   it "should return best dials  as 5 if  best_dials simulated_values is greater than 3" do
      simulated_values = SimulatedValues.create(best_dials: 10.0, best_conversation: 0, longest_conversation: 0)
      attach_simulated_values(campaign, simulated_values)

      expect(campaign.best_dials_simulated).to eq(4)
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

  describe "number of voters to dial" do
    it "should dial one line per caller  if no calls have been made in the last ten minutes" do
      simulated_values = SimulatedValues.create(best_dials: 2.33345, best_conversation: 34.0076, longest_conversation: 42.0876, best_wrapup_time: 10.076)
      attach_simulated_values(campaign, simulated_values)
      2.times do |index|
        caller_session = create(:caller_session, campaign: campaign, :available_for_call => true, :on_call => true)
      end

      num_to_call = campaign.number_of_voters_to_dial
      expect(campaign).not_to receive(:num_to_call_predictive_simulate)

      caller_sessions = CallerSession.find_all_by_campaign_id(campaign.id)
      expect(num_to_call).to eq(caller_sessions.size)
    end

    it "should dial one line per caller if abandonment rate exceeds acceptable rate" do
      simulated_values = SimulatedValues.create(best_dials: 2.33345, best_conversation: 34.0076, longest_conversation: 42.0876, best_wrapup_time: 10.076)
      attach_simulated_values(campaign, simulated_values)
      create(:call_attempt, campaign: campaign, :call_start => 20.seconds.ago)
      create(:call_attempt, campaign: campaign, :call_start => 20.seconds.ago, status: CallAttempt::Status::ABANDONED)
      2.times { create(:caller_session, campaign: campaign, :available_for_call => true, :on_call => true) }

      num_to_call = campaign.number_of_voters_to_dial
      expect(campaign).not_to receive(:num_to_call_predictive_simulate)

      caller_sessions = CallerSession.find_all_by_campaign_id(campaign.id)
      expect(num_to_call).to eq(caller_sessions.size)
    end

    it "should dial one line per caller minus Ringin lines if abandonment rate exceeds acceptable rate" do
      simulated_values = SimulatedValues.create(best_dials: 2.33345, best_conversation: 34.0076, longest_conversation: 42.0876, best_wrapup_time: 10.076)
      attach_simulated_values(campaign, simulated_values)
      create(:call_attempt, campaign: campaign, :call_start => 20.seconds.ago)
      create(:call_attempt, campaign: campaign, :call_start => 20.seconds.ago, status: CallAttempt::Status::ABANDONED)
      2.times { create(:call_attempt, campaign: campaign, :created_at => 10.seconds.ago, status: CallAttempt::Status::RINGING ) }
      3.times { create(:caller_session, campaign: campaign, :available_for_call => true, :on_call => true) }

      num_to_call = campaign.number_of_voters_to_dial
      expect(campaign).not_to receive(:num_to_call_predictive_simulate)

      caller_sessions = CallerSession.find_all_by_campaign_id(campaign.id)
      expect(num_to_call).to eq(1)
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

  describe "number_of_simulated_voters_to_dial" do


   xit "should determine calls to make give the simulated best_dials when call_attempts prior int the last 10 mins are present" do
     simulated_values = SimulatedValues.create(best_dials: 2.33345, best_conversation: 34.0076, longest_conversation: 42.0876, best_wrapup_time: 10.076)
     campaign = create(:predictive, :simulated_values => simulated_values)

     10.times { create(:caller_session, campaign: campaign, :on_call => true, :available_for_call => true) }
     10.times { create(:call_attempt, campaign: campaign, :call_start => 40.seconds.ago, call_end: 10.seconds.ago, :wrapup_time => 5.seconds.ago, status: CallAttempt::Status::SUCCESS) }
     10.times { create(:call_attempt, campaign: campaign, :call_start => 40.seconds.ago, call_end: 8.seconds.ago, status: CallAttempt::Status::SUCCESS) }
     3.times { create(:call_attempt, campaign: campaign, :call_start => 80.seconds.ago, call_end: 38.seconds.ago, status: CallAttempt::Status::SUCCESS) }
     create(:call_attempt, campaign: campaign, :call_start => 35.seconds.ago,call_end: 10.seconds.ago, status: CallAttempt::Status::SUCCESS)
     create(:call_attempt, campaign: campaign, :call_start => 65.seconds.ago, call_end: 10.seconds.ago, status: CallAttempt::Status::SUCCESS)
     2.times { create(:call_attempt, campaign: campaign, :call_start => 10.seconds.ago, status: CallAttempt::Status::RINGING) }
     unavailable_caller_sessions = CallerSession.all[1..7]
     unavailable_caller_sessions.each { |caller_session| caller_session.update_attribute(:available_for_call, false) }
     5.times { create(:call_attempt, campaign: campaign, :call_start => 5.seconds.ago, status: CallAttempt::Status::INPROGRESS) }
     2.times { create(:call_attempt, campaign: campaign, :call_start => 20.seconds.ago, status: CallAttempt::Status::INPROGRESS) }
     expect(campaign.number_of_simulated_voters_to_dial).to eq(18)
   end

   it "should determine calls to make give the simulated best_dials when call_attempts prior int the last 10 mins are present" do
       simulated_values = SimulatedValues.create(best_dials: 1, best_conversation: 0, longest_conversation: 0)
       campaign.simulated_values = simulated_values
       campaign.save!
       3.times do |index|
         caller_session = create(:caller_session, campaign: campaign, :on_call => true, :available_for_call => true)
       end

       expect(campaign.number_of_simulated_voters_to_dial).to eq(3)
   end

   it "should determine calls to make when no simulated values" do
     3.times do |index|
       caller_session = create(:caller_session, campaign: campaign, :on_call => true, :available_for_call => true)
     end

     expect(campaign.number_of_simulated_voters_to_dial).to eq(3)
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
#
