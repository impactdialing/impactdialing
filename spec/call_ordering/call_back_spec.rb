require 'spec_helper'

context 'Message Drops', data_heavy: true do
  include FakeCallData
  let(:admin){ create(:user) }
  let(:account){ admin.account }

  
  def call_and_leave_messages(dial_queue, voter_count, autodropped=0)
    phone_numbers = dial_queue.next(voter_count)
    households    = dial_queue.campaign.households.where(phone: phone_numbers)
    households.each do |household|
      call_attempt = attach_call_attempt(:past_recycle_time_machine_answered_call_attempt, household)
      call_attempt.update_recording!(autodropped)
    end
  end

  describe 'Do not call back after dropping message' do
    let(:campaign) do
      create_campaign_with_script(:power_with_recording, account, {
        answering_machine_detect: true,
        call_back_after_voicemail_delivery: false,
        caller_can_drop_message_manually: true
      }).last
    end
    let(:voters){ add_voters(campaign, :voter, 5) }
    let(:dial_queue) do
      voters
      CallFlow::DialQueue.new(campaign)
    end

    before do
      add_callers(campaign, 1)
      cache_available_voters(campaign)
    end

    it 'When all contacts have received a message automatically' do
      call_and_leave_messages(dial_queue, voters.size, true)
      actual = campaign.next_in_dial_queue

      expect(actual).to be_nil
    end

    it 'When all but one contact have received a message automatically' do
      remaining = voters.pop
      call_and_leave_messages(dial_queue, voters.size, true)
      actual = campaign.next_in_dial_queue

      expect(actual).to eq remaining
    end

    it 'When all contacts have received a message manually' do
      call_and_leave_messages(dial_queue, voters.size, false)
      actual = campaign.next_in_dial_queue

      expect(actual).to be_nil
    end

    it 'When all but one contact have received a message manually' do
      remaining = voters.pop

      call_and_leave_messages(dial_queue, voters.size, false)

      actual = campaign.next_in_dial_queue

      expect(actual).to eq remaining
    end
  end

  describe 'Call back after dropping message' do
    let(:campaign) do
      create_campaign_with_script(:power_with_recording, account, {
        answering_machine_detect: true,
        call_back_after_voicemail_delivery: true,
        caller_can_drop_message_manually: true
      }).last
    end
    let(:voters){ add_voters(campaign, :voter, 5) }
    let(:dial_queue) do
      voters
      CallFlow::DialQueue.new(campaign)
    end

    before do
      add_callers(campaign, 1)
      cache_available_voters(campaign)
    end

    it 'When all contacts have received a message automatically' do
      call_and_leave_messages(dial_queue, voters.size, true)

      process_recycle_bin(campaign)
      actual = campaign.next_in_dial_queue
      # binding.pry
      expect(actual).to eq voters.first.reload
    end

    it 'When all but one contact have received a message automatically' do
      remaining = voters.pop
      call_and_leave_messages(dial_queue, voters.size, true)
      actual = campaign.next_in_dial_queue

      expect(actual).to eq remaining
    end

    it 'When all contacts have received a message manually' do
      call_and_leave_messages(dial_queue, voters.size, false)
      actual = campaign.next_in_dial_queue

      expect(actual).to eq voters.first
    end

    it 'When all but one contact have received a message manually' do
      remaining = voters.pop

      call_and_leave_messages(dial_queue, voters.size, false)
      actual = campaign.next_in_dial_queue

      expect(actual).to eq remaining
    end

    it 'Drop no further messages automatically' do
      call_and_leave_messages(dial_queue, voters.size, true)
      voter = campaign.next_in_dial_queue

      # mimic /calls/:id/incoming
      allow(RedisCall).to receive(:answered_by_machine?){ true }

      actual = voter.call_attempts.last.call.call_answered_by_machine

      expect(actual).to_not include('<Play')
    end
  end
end

context 'Machine Detection without Message Drops' do
  include FakeCallData
  let(:admin){ create(:user) }
  let(:account){ admin.account }

  before do
    Redis.new.flushall
  end

  describe 'Call back after machine detected' do
    let(:campaign) do
      create_campaign_with_script(:power_with_recording, account, {
        answering_machine_detect: true,
        use_recordings: false
      }).last
    end
    let(:dial_queue) do
      CallFlow::DialQueue.new(campaign)
    end

    let!(:voters) do
      create_list(:voter, 5, campaign: campaign, account: campaign.account)
    end

    before do
      expect(Voter.count).to eq 5
      expect(Household.count).to eq 5

      add_callers(campaign, 1)
      
      cache_available_voters(campaign)
      expect(dial_queue.available.size).to eq 5
    end

    def call_and_hangup_on_machine(campaign, count)
      count.times do
        house     = campaign.next_in_dial_queue
        household = campaign.households.where(phone: house[:phone]).first
        attach_call_attempt(:past_recycle_time_machine_answered_call_attempt, household)
      end
    end

    def call_and_answer_by_human(campaign, count)
      count.times do
        house = campaign.next_in_dial_queue
        voter = Voter.find(house[:voters].first[:id])
        attach_call_attempt(:past_recycle_time_completed_call_attempt, voter)
      end
    end

    it 'When the first pass is done and machines were detected for some households, cycle through those households again' do
      call_and_answer_by_human(campaign, 1)
      call_and_hangup_on_machine(campaign, 1)
      call_and_answer_by_human(campaign, 1)
      call_and_hangup_on_machine(campaign, 2)

      expect(dial_queue.available.size).to eq 3
    end
  end
end
