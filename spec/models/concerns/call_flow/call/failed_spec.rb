require 'rails_helper'

describe 'CallFlow::Call::Failed' do
  describe '.create(campaign_id, phone, rest_response)' do
    subject{ CallFlow::Call::Failed }
    let(:instance){ subject.new(campaign_id, phone) }
    let(:campaign_id){ 42 }
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
      subject.create(campaign_id, phone, rest_response)
      expect(instance.storage[:status]).to eq rest_response[:status]
      expect(instance.storage[:error_code]).to eq rest_response[:error_code].to_s
    end

    it 'stores mapped_status of CallAttempt::Status::FAILED' do
      subject.create(campaign_id, phone, rest_response)
      expect(instance.storage[:mapped_status]).to eq CallAttempt::Status::FAILED
    end

    it 'stores phone' do
      subject.create(campaign_id, phone, rest_response)
      expect(instance.storage[:phone]).to eq phone
    end

    it 'stores campaign_id' do
      subject.create(campaign_id, phone, rest_response)
      expect(instance.storage[:campaign_id]).to eq campaign_id.to_s
    end

    it 'queues CallFlow::Jobs::Persistence' do
      subject.create(campaign_id, phone, rest_response)
      expect([:sidekiq, :persistence]).to have_queued(CallFlow::Jobs::Persistence).with('Failed', campaign_id, phone)
    end
  end
end
