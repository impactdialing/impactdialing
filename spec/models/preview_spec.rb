require "spec_helper"


describe Preview, :type => :model do
  include FakeCallData

  let(:admin){ create(:user) }
  let(:account){ admin.account }
  let(:campaign) do
    create_campaign_with_script(:bare_preview, account).last
  end
  let(:caller) do
    create(:caller)
  end

  def skip_voters(voters)
    voters.each{|v| v.skip; v.save! }
  end

  def dial_all_one_at_a_time(campaign, &block)
    campaign.all_voters.available_list(campaign).count.times do
      voter = campaign.next_in_dial_queue
      yield voter
    end
  end

  def dial_one_at_a_time(campaign, n, &block)
    n.times do 
      voter = campaign.next_in_dial_queue
      yield voter
    end
  end

  describe 'dialing' do
    before do
      ENV['USE_REDIS_DIAL_QUEUE'] = '0'
      add_voters(campaign, :realistic_voter, 5)
    end
    let(:dial_queue) do
      CallFlow::DialQueue.new(campaign)
    end
    context 'skipped voters' do

      it 'are cycled through until called; ie the campaign does not run out of numbers while some voters have been skipped' do
        # binding.pry
        dial_one_at_a_time(campaign, 1){|voter| skip_voters([voter])}

        dial_one_at_a_time(campaign, 4){|voter| attach_call_attempt(:completed_call_attempt, voter, caller)}

        # make 3 more passes through the list. this really means reloading the same voter
        # each time it's skipped since all other voters have been called.
        3.times do
          voter = campaign.next_in_dial_queue
          expect(voter).to eq Voter.first
          skip_voters([voter])
        end

        # 4th pass, call voter this time
        voter = campaign.next_in_dial_queue
        expect(voter).to eq Voter.first
        attach_call_attempt(:completed_call_attempt, voter, caller)

        # 5th pass should return nil, since all voters have now been dialed
        voter = campaign.next_in_dial_queue
        expect(voter).to be_nil
      end
    end
  end

  describe "next voter to be dialed" do
    def setup_voters(campaign_opts={}, voter_opts={})
      @campaign = create(:preview, campaign_opts.merge({
        recycle_rate: 1
      }))
      vopt = voter_opts.merge({
        campaign: @campaign,
        enabled: [:list]
      })
      create_list(:realistic_voter, 10, vopt)
      expect(Voter.count).to eq 10
      @voters = @campaign.all_voters
      last_call_time = 20.hours.ago
      @voters.order('id ASC').each do |v|
        v.update_attribute(:last_call_attempt_time, last_call_time)
        last_call_time += 1.hour
      end
      @dial_queue = cache_available_voters(@campaign)
    end

    let(:campaign){ create(:preview) }
    let(:dial_queue){ CallFlow::DialQueue.new(campaign) }
    it_behaves_like 'Preview/Power#next_voter_in_dial_queue'

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
      vone = create(:realistic_voter, vopt)
      vtwo = create(:realistic_voter, vopt)
      vthr = create(:realistic_voter, vopt)
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
