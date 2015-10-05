require 'rails_helper'

describe 'CallFlow::Call::Failed' do
  describe '.create(campaign_id, phone, rest_response)' do
    subject{ CallFlow::Call::Failed }
    let(:instance){ subject.new(campaign_id, phone) }
    let(:campaign) do
      instance_double('Power', {
        id: 42,
        dial_queue: instance_double('CallFlow::DialQueue', {
          failed!: nil
        })
      })
    end
    let(:campaign_id){ campaign.id }
    let(:phone){ Forgery(:address).clean_phone }
    let(:rest_response) do
      {
        status: 'failed',
        error_code: 123
      }
    end

    it 'raises CallFlow::Call::InvalidParams when campaign_id is blank' do
      expect{ subject.create('', phone, rest_response) }.to raise_error(CallFlow::Call::InvalidParams)
    end

    it 'raises CallFlow::Call::InvalidParams when phone is blank' do
      expect{ subject.create(campaign_id, '', rest_response) }.to raise_error(CallFlow::Call::InvalidParams)
    end

    it 'stores rest response' do
      subject.create(campaign, phone, rest_response)
      expect(instance.storage[:status]).to eq rest_response[:status]
      expect(instance.storage[:error_code]).to eq rest_response[:error_code].to_s
    end

    it 'stores mapped_status of CallAttempt::Status::FAILED' do
      subject.create(campaign, phone, rest_response)
      expect(instance.storage[:mapped_status]).to eq CallAttempt::Status::FAILED
    end

    it 'stores phone' do
      subject.create(campaign, phone, rest_response)
      expect(instance.storage[:phone]).to eq phone
    end

    it 'stores campaign_id' do
      subject.create(campaign, phone, rest_response)
      expect(instance.storage[:campaign_id]).to eq campaign_id.to_s
    end

    it 'queues CallFlow::Jobs::Persistence' do
      subject.create(campaign, phone, rest_response)
      expect([:sidekiq, :persistence]).to have_queued(CallFlow::Jobs::Persistence).with('Failed', campaign_id, phone)
    end

    context 'telling CallFlow::DialQueue of the failed dial' do
      it 'update_presented is false by default' do
        expect(campaign.dial_queue).to receive(:failed!).with(phone, false)
        subject.create(campaign, phone, rest_response)
      end

      it 'passes the update_presented flag to DialQueue#failed!' do
        expect(campaign.dial_queue).to receive(:failed!).with(phone, true)
        subject.create(campaign, phone, rest_response, true)
      end
    end
  end
end

