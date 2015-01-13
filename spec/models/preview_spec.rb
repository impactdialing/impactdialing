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
    # voters.each_with_index do |v, i|
    #   v.update_attributes!(skipped_time: (25.hours.ago + i.minutes), status: Voter::Status::SKIPPED)
    # end
  end

  def dial_all_one_at_a_time(campaign, &block)
    campaign.all_voters.available_list(campaign).count.times do
      house = campaign.next_in_dial_queue
      yield house
      house
    end
  end

  def dial_one_at_a_time(campaign, n, &block)
    n.times do 
      house = campaign.next_in_dial_queue
      yield house
      house
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
      it 'are made available again' do
        skipped = []
        busy    = []
        dial_one_at_a_time(campaign, 1) do |house|
          skipped << house
        end # skipping
        dial_one_at_a_time(campaign, 1) do |house|
          busy << house
          attach_call_attempt(:busy_call_attempt, Household.find_by_phone(house[:phone]), caller)
        end

        current_time = Time.now
        Timecop.travel(current_time + campaign.recycle_rate.hours + 1.hour) do
          process_presented(campaign)

          expect(dial_queue.available.all[-2]).to eq skipped.first[:phone]
          dial_one_at_a_time(campaign, 1) do |house|
            voter        = Voter.find(house[:voters].first[:id])
            attach_call_attempt(:completed_call_attempt, voter, caller)
          end
          dial_one_at_a_time(campaign, 1) do |house|
            skipped << house
          end # skipping
          dial_one_at_a_time(campaign, 1) do |house|
            call_attempt = attach_call_attempt(:failed_call_attempt, Household.find_by_phone(house[:phone]), caller)
            call_attempt.household.failed!
          end

          current_time = Time.now
          Timecop.travel(current_time + campaign.recycle_rate.hours + 1.minute) do
            process_presented(campaign)
            expect(dial_queue.available.all).to eq [skipped.first[:phone], busy.first[:phone], skipped.last[:phone]]
          end
        end
      end

      it 'voters are moved to the front of the list (after recycle rate) for subsequent passes' do
        skipped  = []
        busy     = []
        complete = []
        dial_one_at_a_time(campaign, 1){|house| skipped << house}
        dial_one_at_a_time(campaign, 2){|house| busy << house && attach_call_attempt(:past_recycle_time_busy_call_attempt, Household.find_by_phone(house[:phone]), caller)}
        dial_one_at_a_time(campaign, 1){|house| skipped << house}
        dial_one_at_a_time(campaign, 1){|house| complete << house && attach_call_attempt(:past_recycle_time_completed_call_attempt, Voter.find(house[:voters].first[:id]), caller)}
        
        expect(dial_queue.available.all.size).to eq 0

        current_time = Time.now
        Timecop.travel(current_time + campaign.recycle_rate.hours + 1.minute) do
          process_presented(campaign)

          expect(campaign.next_in_dial_queue).to eq skipped.first
          expect(campaign.next_in_dial_queue).to eq skipped.last
          expect(busy).to include campaign.next_in_dial_queue
        end
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
      it_behaves_like 'Preview/Power#next_in_dial_queue'
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
          actual = @campaign.next_in_dial_queue
          expect(actual[:voters].first[:id]).to eq expected.id
        end
      end
      context 'one voter has not been skipped' do
        it 'returns the unskipped voter with id > current_voter_id' do
          @dial_queue.next(3)
          @dial_queue.next(4)
          @dial_queue.next(1)

          expected = @voters[8]
          actual = @campaign.next_in_dial_queue

          expect(actual[:voters].first[:id]).to eq expected.id
        end
      end
      context 'more than one voter has not been skipped' do
        it 'returns the first unskipped voter with id > current_voter_id' do
          @dial_queue.next(5)
          skip_voters @voters[0..4]
          @dial_queue.next(2)
          skip_voters @voters[5..6]

          expected = @voters[7]
          actual = @campaign.next_in_dial_queue
          expect(actual[:voters].first[:id]).to eq expected.id
        end
      end
    end

    it 'does not cycle through a sub-set of available voters' do
      setup_voters
      Voter.update_all(last_call_attempt_time: nil)
      @dial_queue = cache_available_voters(@campaign)

      expected = @voters[0]
      actual = @campaign.next_in_dial_queue
      expect(actual[:voters].first[:id]).to eq expected.id

      expected = @voters[1]
      actual = @campaign.next_in_dial_queue
      expect(actual[:voters].first[:id]).to eq expected.id

      expected = @voters[2]
      actual = @campaign.next_in_dial_queue
      expect(actual[:voters].first[:id]).to eq expected.id

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

      expect(campaign.next_in_dial_queue[:voters].first[:id]).to eq vone.id

      vone.reload.skip

      next_voter = campaign.next_in_dial_queue
      expect(next_voter[:voters].first[:id]).not_to eq vone.id
      expect(next_voter[:voters].first[:id]).to eq vtwo.id

      vtwo.reload.skip

      next_voter = campaign.next_in_dial_queue
      expect(next_voter[:voters].first[:id]).not_to eq vtwo.id
      expect(next_voter[:voters].first[:id]).to eq vthr.id

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
# **`households_count`**                    | `integer`          | `default(0)`
#
