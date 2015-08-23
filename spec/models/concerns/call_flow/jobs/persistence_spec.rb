require 'rails_helper'

describe 'CallFlow::Jobs::Persistence' do
  shared_examples_for 'any type of persistence' do
    it 'instantiates the given type, passing args' do
      expect(CallFlow::Persistence::Call::Completed).to receive(:new).with(*expected_args)
      subject.perform(type, *expected_arguments)
    end

    it 'calls #persist_call_outcome on instance of given type'
  end

  context 'type is Completed' do
    let(:account_sid){ 'twilio-account-sid' }
    let(:call_sid){ 'twilio-call-sid' }
    let(:type){ 'Completed' }
    let(:expected_arguments){ [account_sid, call_sid] }

    it_behaves_like 'any type of persistence'
  end

  context 'type is Failed' do
    let(:campaign_id){ '42' }
    let(:phone){ Forgery(:address).clean_phone }
    let(:type){ 'Failed' }
    let(:expected_arguments){ [campaign_id, phone] }

    it_behaves_like 'any type of persistence'
  end
end

