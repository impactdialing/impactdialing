require 'rails_helper'

describe 'CallFlow::Jobs::Persistence' do
  subject{ CallFlow::Jobs::Persistence.new }
  shared_examples_for 'any type of persistence' do
    before do
      allow(type).to receive(:new).with(*expected_arguments){ type_instance }
    end
    it 'instantiates the given type, passing args' do
      expect(type).to receive(:new).with(*expected_arguments){ type_instance }
      subject.perform(type.to_s.split('::').last, *expected_arguments)
    end

    it 'calls #persist_call_outcome on instance of given type' do
      expect(type_instance).to receive(:persist_call_outcome)
      subject.perform(type.to_s.split('::').last, *expected_arguments)
    end
  end

  context 'type is Completed' do
    let(:account_sid){ 'twilio-account-sid' }
    let(:call_sid){ 'twilio-call-sid' }
    let(:type){ CallFlow::Persistence::Call::Completed }
    let(:type_instance) do
      instance_double(type, {persist_call_outcome: nil})
    end
    let(:expected_arguments){ [account_sid, call_sid] }

    it_behaves_like 'any type of persistence'
  end

  context 'type is Failed' do
    let(:campaign_id){ '42' }
    let(:phone){ Forgery(:address).clean_phone }
    let(:type){ CallFlow::Persistence::Call::Failed }
    let(:type_instance) do
      instance_double(type, {persist_call_outcome: nil})
    end
    let(:expected_arguments){ [campaign_id, phone] }

    it_behaves_like 'any type of persistence'
  end
end

