require "spec_helper"


describe Preview, :type => :model do
  include FakeCallData

  describe "next voter to be dialed" do
    def setup_voters(campaign_opts={}, voter_opts={})
      @campaign = create(:preview, campaign_opts.merge({
        recycle_rate: 1
      }))
      vopt = voter_opts.merge({
        campaign: @campaign,
        enabled: true
      })
      create_list(:voter, 10, vopt)
      expect(Voter.count).to eq 10
      @voters = @campaign.all_voters
      last_call_time = 20.hours.ago
      @voters.order('id ASC').each do |v|
        v.update_attribute(:last_call_attempt_time, last_call_time)
        last_call_time += 1.hour
      end
      @dial_queue = cache_available_voters(@campaign)
    end

    def skip_voters(voters)
      voters.each{|v| v.update_attribute('skipped_time', 20.minutes.ago) }
    end

    xit "returns priority not called voter first" do
      campaign = create(:preview)
      voter = create(:voter, status: 'not called', campaign: campaign)
      priority_voter = create(:voter, status: 'not called', campaign: campaign, priority: "1")
      caller_session = create(:caller_session)
      expect(campaign.next_voter_in_dial_queue(nil)).to eq(priority_voter)
    end

    it "returns uncalled voter before called voter" do
      campaign = create(:preview)
      caller_session = create(:caller_session)
      create(:voter, status: CallAttempt::Status::SUCCESS, last_call_attempt_time: 2.hours.ago, campaign: campaign)
      uncalled_voter = create(:voter, status: Voter::Status::NOTCALLED, campaign: campaign)
      cache_available_voters(campaign)
      expect(campaign.next_voter_in_dial_queue(nil)).to eq(uncalled_voter)
    end

    xit "returns any scheduled voter within a ten minute window before an uncalled voter" do
      campaign = create(:preview)
      caller_session = create(:caller_session)
      scheduled_voter = create(:voter, status: CallAttempt::Status::SCHEDULED, last_call_attempt_time: 2.hours.ago, scheduled_date: 1.minute.from_now, campaign: campaign)
      create(:voter, status: Voter::Status::NOTCALLED, campaign: campaign)
      expect(campaign.next_voter_in_dial_queue(nil)).to eq(scheduled_voter)
    end

    xit "returns next voter in list if scheduled voter is more than 10 minutes away from call" do
      campaign = create(:preview)
      caller_session = create(:caller_session)
      scheduled_voter = create(:voter, status: CallAttempt::Status::SCHEDULED, last_call_attempt_time: 2.hours.ago, scheduled_date: 20.minute.from_now, campaign: campaign)
      current_voter = create(:voter, status: Voter::Status::NOTCALLED, campaign: campaign)
      next_voter = create(:voter, status: Voter::Status::NOTCALLED, campaign: campaign)
      expect(campaign.next_voter_in_dial_queue(current_voter.id)).to eq(next_voter)
    end


    it "returns voter with respect to a current voter" do
      campaign = create(:preview)
      caller_session = create(:caller_session)
      uncalled_voter = create(:voter, status: Voter::Status::NOTCALLED, campaign: campaign)
      current_voter = create(:voter, status: Voter::Status::NOTCALLED, campaign: campaign)
      next_voter = create(:voter, status: Voter::Status::NOTCALLED, campaign: campaign)
      dial_queue = cache_available_voters(campaign)
      dial_queue.next(2) # pop the uncalled & current voter off the list, this test is a bit silly
                         # todo: fix or remove this test
      expect(campaign.next_voter_in_dial_queue(current_voter.id)).to eq(next_voter)
    end

    it "returns no number if only voter to be called a retry and last called time is within campaign recycle rate" do
      campaign        = create(:preview, recycle_rate: 2)
      scheduled_voter = create(:voter, first_name: 'scheduled voter', status: CallAttempt::Status::SCHEDULED, last_call_attempt_time: 119.minutes.ago, scheduled_date: 20.minutes.from_now, campaign: campaign)
      retry_voter     = create(:realistic_voter, :voicemail, :recently_dialed, campaign: campaign)
      current_voter   = create(:realistic_voter, :success, :not_recently_dialed, campaign: campaign)
      actual          = campaign.next_voter_in_dial_queue(current_voter.id)

      expect(actual).to be_nil
    end

    it 'does not return any voter w/ a phone number in the blocked number list' do
      blocked = ['1234567890', '0987654321']
      account = create(:account)
      campaign = create(:preview, {account: account})
      allow(account).to receive_message_chain(:blocked_numbers, :for_campaign, :pluck){ blocked }
      voter = create(:voter, status: 'not called', campaign: campaign, phone: blocked.first)
      priority_voter = create(:voter, status: 'not called', campaign: campaign, priority: "1", phone: blocked.second)
      caller_session = create(:caller_session)
      expect(campaign.next_voter_in_dial_queue(nil)).to be_nil
    end

    context 'current_voter_id is not present' do
      before do
        setup_voters
      end
      context 'all voters have been skipped' do
        it 'returns the first voter with the oldest last_call_attempt_time' do
          actual = @campaign.next_voter_in_dial_queue(nil)
          expected = @voters.first
          expect(actual).to eq expected
        end
      end
      context 'one voter has not been skipped' do
        it 'returns the first unskipped voter' do
          skip_voters @voters[0..7]
          @dial_queue.next(8) # pop first 8 voters off the list
          expected = @voters[8]
          actual = @campaign.next_voter_in_dial_queue(nil)
          expect(actual).to eq expected
        end
      end
      context 'more than one voter has not been skipped' do
        it 'returns the first unskipped voter with the oldest last_call_attempt_time' do
          skip_voters @voters[3..7]
          expected = @voters[0]
          actual = @campaign.next_voter_in_dial_queue(nil)
          expect(actual).to eq expected
        end
      end
    end

    context 'current_voter_id is present' do
      before do
        setup_voters
        @current_voter = @voters[3]
      end
      context 'all voters have been skipped' do
        it 'returns the voter with id > current_voter_id' do
          skip_voters @voters
          @dial_queue.next(4) # pop first 4 voters (up to @voters[3])
          expected = @voters[4]
          actual = @campaign.next_voter_in_dial_queue(@current_voter.id)
          expect(actual).to eq expected
        end
      end
      context 'one voter has not been skipped' do
        it 'returns the unskipped voter with id > current_voter_id' do
          skip_voters @voters[0..2]
          skip_voters @voters[4..7]
          skip_voters [@voters[9]]
          @dial_queue.next(8)
          expected = @voters[8]
          actual = @campaign.next_voter_in_dial_queue(@current_voter.id)
          expect(actual).to eq expected
        end
      end
      context 'more than one voter has not been skipped' do
        it 'returns the first unskipped voter with id > current_voter_id' do
          skip_voters @voters[0..2]
          skip_voters @voters[5..6]
          @dial_queue.next(4)
          expected = @voters[4]
          actual = @campaign.next_voter_in_dial_queue(@current_voter.id)
          expect(actual).to eq expected
        end
      end
    end

    it 'does not cycle through a sub-set of available voters' do
      setup_voters
      expected = @voters[0]
      actual = @campaign.next_voter_in_dial_queue(nil)
      expect(actual).to eq expected

      actual.skip
      actual.reload

      expected = @voters[1]
      actual = @campaign.next_voter_in_dial_queue(actual.id)
      expect(actual).to eq expected

      actual.skip
      actual.reload

      expected = @voters[2]
      actual = @campaign.next_voter_in_dial_queue(actual.id)
      expect(actual).to eq expected
    end

    it 'never returns the current voter when that voter has been skipped' do
      campaign = create(:preview)
      vopt = {
        campaign: campaign
      }
      vone = create(:voter, vopt)
      vtwo = create(:voter, vopt)
      vthr = create(:voter, vopt)
      cache_available_voters(campaign)

      expect(campaign.next_voter_in_dial_queue(nil)).to eq vone

      vone.reload.skip

      next_voter = campaign.next_voter_in_dial_queue(vone.id)
      expect(next_voter).not_to eq vone
      expect(next_voter).to eq vtwo

      vtwo.reload.skip

      next_voter = campaign.next_voter_in_dial_queue(vtwo.id)
      expect(next_voter).not_to eq vtwo
      expect(next_voter).to eq vthr
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
