require 'spec_helper'

context 'Message Drops', data_heavy: true do
  include FakeCallData
  let(:admin){ create(:user) }
  let(:account){ admin.account }

  describe 'Do not call back after dropping message' do
    let(:campaign) do
      create_campaign_with_script(:power_with_recording, account, {
        answering_machine_detect: true,
        call_back_after_voicemail_delivery: false,
        caller_can_drop_message_manually: true
      }).last
    end
    let(:voters){ add_voters(campaign, 5) }

    before do
      add_callers(campaign, 1)
    end

    it 'When all contacts have received a message automatically' do
      call_and_leave_messages(voters, true)

      actual = campaign.next_voter_in_dial_queue(voters.last)

      expect(actual).to be_nil
    end

    it 'When all but one contact have received a message automatically' do
      remaining = voters.pop

      call_and_leave_messages(voters, true)

      actual = campaign.next_voter_in_dial_queue(voters.last)

      expect(actual).to eq remaining
    end

    it 'When all contacts have received a message manually' do
      call_and_leave_messages(voters, false)

      actual = campaign.next_voter_in_dial_queue(voters.last)

      expect(actual).to be_nil
    end

    it 'When all but one contact have received a message manually' do
      remaining = voters.pop

      call_and_leave_messages(voters, false)

      actual = campaign.next_voter_in_dial_queue(voters.last)

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
    let(:voters){ add_voters(campaign, 5) }

    before do
      add_callers(campaign, 1)
    end

    it 'When all contacts have received a message automatically' do
      call_and_leave_messages(voters, true)

      actual = campaign.next_voter_in_dial_queue(voters.last)

      expect(actual).to eq voters.first
    end

    it 'When all but one contact have received a message automatically' do
      remaining = voters.pop

      call_and_leave_messages(voters, true)

      actual = campaign.next_voter_in_dial_queue(voters.last)

      expect(actual).to eq remaining
    end

    it 'When all contacts have received a message manually' do
      call_and_leave_messages(voters, false)

      actual = campaign.next_voter_in_dial_queue(voters.last)

      expect(actual).to eq voters.first
    end

    it 'When all but one contact have received a message manually' do
      remaining = voters.pop

      call_and_leave_messages(voters, false)

      actual = campaign.next_voter_in_dial_queue(voters.last)

      expect(actual).to eq remaining
    end

    it 'Drop no further messages automatically' do
      call_and_leave_messages(voters, true)

      voter = campaign.next_voter_in_dial_queue(nil)

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

  describe 'Call back after machine detected' do
    let(:campaign) do
      create_campaign_with_script(:power_with_recording, account, {
        answering_machine_detect: true
      }).last
    end
    let(:voters){ add_voters(campaign, 5) }

    before do
      add_callers(campaign, 1)
    end

    def call_and_hangup_on_machine(voters)
      voters.each do |voter|
        attach_call_attempt(:past_recycle_time_machine_answered_call_attempt, voter)
      end
    end

    def call_and_answer_by_human(voters)
      voters.each do |voter|
        attach_call_attempt(:past_recycle_time_completed_call_attempt, voter)
      end
    end

    it 'When the first pass is done and machines were detected for some voters, cycle through those voters again' do
      call_and_answer_by_human([voters[1], voters[3]])
      call_and_hangup_on_machine([voters[0], voters[2], voters[4]])

      actual = campaign.next_voter_in_dial_queue(nil)

      expect(actual).to eq voters[0]
      call_and_answer_by_human([actual])

      actual = campaign.next_voter_in_dial_queue(actual)
      expect(actual).to eq voters[2]
      call_and_answer_by_human([actual])

      actual = campaign.next_voter_in_dial_queue(actual)
      expect(actual).to eq voters[4]
    end
  end
end
