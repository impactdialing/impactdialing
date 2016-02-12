require 'rails_helper'

describe 'CallFlow::Web::ContactFields' do
  let(:fields){ ['name', 'email', 'address'] }
  let(:account){ create(:account) }
  let(:script){ create(:script, account: account) }
  let(:valid_arg) do
    {
      script: script,
      account: account
    }
  end
  subject{ CallFlow::Web::ContactFields.new(valid_arg) }

  describe 'instantiating' do
    subject{ CallFlow::Web::ContactFields }
    it 'accepts a hash of objects: {script, account}' do
      expect(subject.new(valid_arg)).to be_kind_of subject
    end
    it 'exposes script' do
      instance = subject.new(valid_arg)
      expect(instance.script).to eq script
    end
    it 'exposes account' do
      instance = subject.new(valid_arg)
      expect(instance.account).to eq account
    end
  end

  describe '#selected' do
    it 'returns an instance of CallFlow::Web::ContactFields::Selected' do
      expect(subject.selected).to be_kind_of CallFlow::Web::ContactFields::Selected
    end
  end

  describe '#options' do
    it 'returns an instance of CallFlow::Web::ContactFields::Options' do
      expect(subject.options).to be_kind_of CallFlow::Web::ContactFields::Options
    end
  end
end
