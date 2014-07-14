require 'spec_helper'

describe AnsweringMachineAgent do
  let(:campaign) do
    create(:power, {
      answering_machine_detect: true
    })
  end
  let(:voters) do
    create_list(:voter, 10, {
      campaign: campaign
    })
  end
  let(:voter) do
    voters.first
  end
  let(:subject){ AnsweringMachineAgent.new(voter) }

  describe '#leave_message?' do
    context 'campaign is not set to leave messages' do
      before do
        campaign.update_attribute(:use_recordings, false)
      end
      it 'returns false' do
        subject.leave_message?.should be_falsey
      end
    end

    context 'campaign is set to leave messages AND' do
      before do
        campaign.update_attribute(:use_recordings, true)
      end
      context 'campaign is set to call back after leaving a message AND' do
        before do
          campaign.update_attribute(:call_back_after_voicemail_delivery, true)
        end
        context 'a message has not been left for this contact' do
          before do
            voter.update_attribute(:voicemail_history, '')
          end
          it 'returns true' do
            subject.leave_message?.should be_truthy
          end
        end

        context 'a message has been left for this contact' do
          before do
            voter.update_attribute(:voicemail_history, '12')
          end
          it 'returns false' do
            subject.leave_message?.should be_falsey
          end
        end
      end

      context 'campaign is not set to call back after leaving a message' do
        it 'returns true' do
          subject.leave_message?.should be_truthy
        end
      end
    end
  end

  describe '#call_back?' do
    context 'campaign is set to leave a message' do
      before do
        campaign.update_attribute(:use_recordings, true)
      end
      context 'campaign is set to call back after leaving a message' do
        before do
          campaign.update_attribute(:call_back_after_voicemail_delivery, true)
        end
        it 'returns true' do
          subject.call_back?.should be_truthy
        end
      end
      context 'campaign is not set to call back after leaving a message' do
        before do
          campaign.update_attribute(:call_back_after_voicemail_delivery, false)
        end
        it 'returns false' do
          subject.call_back?.should be_falsey
        end
      end
    end

    context 'campaign is set to detect machines but not leave a message' do
      context 'campaign is set to call back after leaving a message' do
        before do
          campaign.update_attribute(:call_back_after_voicemail_delivery, true)
        end
        it 'returns true' do
          subject.call_back?.should be_truthy
        end
      end
      context 'campaign is not set to call back after leaving a message' do
        before do
          campaign.update_attribute(:call_back_after_voicemail_delivery, false)
        end
        it 'returns true' do
          subject.call_back?.should be_truthy
        end
      end
    end
  end
end