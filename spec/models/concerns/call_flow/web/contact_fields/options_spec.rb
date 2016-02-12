require 'rails_helper'

describe 'CallFlow::Web::ContactFields::Options' do
  let(:account){ create(:account) }
  let(:key){ "contact_fields:options:#{account.id}" }
  let(:new_fields) do
    [
      'Polling location',
      'Polling Description',
      'Gender'
    ]
  end
  subject{ CallFlow::Web::ContactFields::Options.new(account) }

  describe 'instantiating' do
    subject{ CallFlow::Web::ContactFields::Options }

    it 'requires a saved Account instance for first arg' do
      expect{
        subject.new(build(:account))
      }.to raise_error(ArgumentError)
    end
  end

  describe 'saving custom field options' do
    it '#save(arr) stores given Array elements as SET' do
      subject.save(new_fields)
      saved_fields = redis.smembers key
      expect(saved_fields).to match_array new_fields
    end

    it 'does not save blank elements' do
      subject.save([' ', '', 'one'])
      saved_fields = redis.smembers key
      expect(saved_fields).to match_array ['one']
    end

    it 'does nothing when saving an empty array' do
      expect{ subject.save([]) }.to_not raise_error
      expect{ subject.save(['', ' ']) }.to_not raise_error
    end
  end

  describe 'retrieving saved custom field options' do
    it '#all returns all members of SET' do
      subject.save(new_fields)
      expect(subject.all).to match_array new_fields
    end
  end
end

