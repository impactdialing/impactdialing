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

  before do
    Redis.new.flushall
  end

  def skip_voters(voters)
    dial_queue = CallFlow::DialQueue.new(voters.first.campaign)
    voters.each_with_index do |v, i|
      v.update_attributes!(skipped_time: (25.hours.ago + i.minutes), status: Voter::Status::SKIPPED)
      dial_queue.dialed(v)
    end
  end

  def dial_all_one_at_a_time(campaign, &block)
    campaign.all_voters.available_list(campaign).count.times do
      voter = campaign.next_in_dial_queue
      yield voter
      voter
    end
  end

  def dial_one_at_a_time(campaign, n, &block)
    n.times do 
      voter = campaign.next_in_dial_queue
      yield voter
      voter
    end
  end

  describe 'dialing' do
    before do
      ENV['USE_REDIS_DIAL_QUEUE'] = '1'
      add_voters(campaign, :voter, 5)
    end
    let(:dial_queue) do
      CallFlow::DialQueue.new(campaign)
    end
    context 'skipped voters' do
      it 'are moved to the end of the list' do
        dial_one_at_a_time(campaign, 1){|voter| skip_voters([voter])}

        dial_one_at_a_time(campaign, 1){|voter| attach_call_attempt(:busy_call_attempt, voter, caller)}

        process_recycle_bin(campaign)

        # in real-world, skipping a voter causes next voter to load right away, so check for skipped voter
        # to be re-added to list after following voter is dialed
        last_on_queue = dial_queue.available.all.last

        # binding.pry
        # cuz first voter was skipped, it should now be at tail
        expect(last_on_queue).to eq Voter.first.phone

        dial_one_at_a_time(campaign, 1){|voter| attach_call_attempt(:completed_call_attempt, voter, caller)}

        dial_one_at_a_time(campaign, 1){|voter| skip_voters([voter])}

        dial_one_at_a_time(campaign, 1){|voter| attach_call_attempt(:failed_call_attempt, voter, caller)}

        process_recycle_bin(campaign)

        last_on_queue = dial_queue.available.all.last
        penultimate_on_queue = dial_queue.available.all[-2]

        # binding.pry

        expect(last_on_queue).to eq Voter.all[3].phone # last voter that was skipped
        expect(penultimate_on_queue).to eq Voter.all[0].phone # voter skipped previously
      end

      it 'are cycled through until called; ie the campaign does not run out of numbers while some voters have been skipped' # do
      #   # binding.pry
      #   dial_one_at_a_time(campaign, 1){|voter| skip_voters([voter])}

      #   dial_one_at_a_time(campaign, 4){|voter| attach_call_attempt(:completed_call_attempt, voter, caller)}

      #   # make 3 more passes through the list. this really means reloading the same voter
      #   # each time it's skipped since all other voters have been called.

      #   3.times do
      #     top_off(dial_queue)
      #     voter = campaign.next_in_dial_queue

      #     expect(voter).to eq Voter.first
      #     skip_voters([voter])
      #   end

      #   # 4th pass, call voter this time
      #   voter = campaign.next_in_dial_queue
      #   expect(voter).to eq Voter.first
      #   attach_call_attempt(:completed_call_attempt, voter, caller)

      #   # 5th pass should return nil, since all voters have now been dialed
      #   voter = campaign.next_in_dial_queue
      #   expect(voter).to be_nil
      # end

      it 'voters are presented in the same order on every pass' do
        # binding.pry
        skipped  = []
        busy     = []
        complete = []
        dial_one_at_a_time(campaign, 1){|voter| skipped << voter && skip_voters([voter])}
        dial_one_at_a_time(campaign, 2){|voter| busy << voter && attach_call_attempt(:past_recycle_time_busy_call_attempt, voter, caller)}
        dial_one_at_a_time(campaign, 1){|voter| skipped << voter && skip_voters([voter])}
        dial_one_at_a_time(campaign, 1){|voter| complete << voter && attach_call_attempt(:past_recycle_time_completed_call_attempt, voter, caller)}

        process_recycle_bin(campaign)
        
        expected_skipped = skipped.first
        first_skipped    = campaign.next_in_dial_queue

        expect(first_skipped).to eq skipped.first
        attach_call_attempt(:busy_call_attempt, first_skipped, caller)

        expected_busy = busy.first
        actual_busy   = campaign.next_in_dial_queue

        expect(actual_busy).to eq expected_busy
        attach_call_attempt(:completed_call_attempt, actual_busy, caller)
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
      create_list(:voter, 10, vopt)
      expect(Voter.count).to eq 10
      @voters = @campaign.all_voters
      last_call_time = 36.hours.ago
      @voters.order('id ASC').each do |v|
        v.update_attribute(:last_call_attempt_time, last_call_time)
        last_call_time += (120 + v.id)
      end
      @dial_queue = cache_available_voters(@campaign)
    end

    context 'shared behaviors' do
      # let(:campaign){ create(:preview) }
      after do
        redis = Redis.new
        redis.flushall
      end
      it_behaves_like 'Preview/Power#next_voter_in_dial_queue'
    end

    context 'skipping voters' do
      before do
        setup_voters
        @current_voter = @voters[3]
      end
      after do
        redis = @dial_queue.available.send :redis
        redis.flushall
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
          @dial_queue.next(3)
          skip_voters @voters[0..2]
          @dial_queue.next(4)
          skip_voters @voters[3..6]
          @dial_queue.next(1)
          skip_voters [@voters[7]]

          expected = @voters[8]
          actual = @campaign.next_voter_in_dial_queue

          expect(actual).to eq expected
        end
      end
      context 'more than one voter has not been skipped' do
        it 'returns the first unskipped voter with id > current_voter_id' do
          @dial_queue.next(5)
          skip_voters @voters[0..4]
          @dial_queue.next(2)
          skip_voters @voters[5..6]

          expected = @voters[7]
          actual = @campaign.next_voter_in_dial_queue(@current_voter.id)
          expect(actual).to eq expected
        end
      end
    end

    it 'does not cycle through a sub-set of available voters' do
      setup_voters
      Voter.update_all(last_call_attempt_time: nil)
      @dial_queue = cache_available_voters(@campaign)

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

      redis = @dial_queue.available.send :redis
      redis.flushall
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

      redis = Redis.new
      redis.flushall
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
