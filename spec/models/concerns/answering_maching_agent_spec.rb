require 'rails_helper'

describe AnsweringMachineAgent do
  let(:campaign) do
    create(:power, {
      answering_machine_detect: true
    })
  end
  let(:households) do
    double('DialQueue::Households', no_message_dropped?: true)
  end
  let(:phone){ Forgery('address').clean_phone }
  let(:subject){ AnsweringMachineAgent.new(campaign, phone) }

  before do
    allow(campaign).to receive_message_chain(:dial_queue, :households){ households }
  end

  describe '#leave_message?' do
    context 'campaign is not set to leave messages' do
      before do
        campaign.update_attribute(:use_recordings, false)
      end
      it 'returns false' do
        expect(subject.leave_message?).to be_falsey
      end
    end

    context 'campaign is set to leave messages AND' do
      before do
        campaign.update_attribute(:use_recordings, true)
      end
      context 'call back after leaving a message AND' do
        before do
          campaign.update_attribute(:call_back_after_voicemail_delivery, true)
        end
        context 'a message has not been left for this contact' do
          it 'returns true' do
            expect(subject.leave_message?).to be_truthy
          end
        end

        context 'a message has been left for this contact' do
          before do
            allow(households).to receive(:no_message_dropped?){ false }
          end
          it 'returns false' do
            expect(subject.leave_message?).to be_falsey
          end
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
          expect(subject.call_back?).to be_truthy
        end
      end
      context 'campaign is not set to call back after leaving a message' do
        before do
          campaign.update_attribute(:call_back_after_voicemail_delivery, false)
        end
        it 'returns false' do
          expect(subject.call_back?).to be_falsey
        end
      end
    end
  end
end
