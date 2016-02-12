require 'rails_helper'

describe 'CallFlow::Web::ContactFields::Selected' do
  let(:instance){ create(:script) }
  let(:invalid_instance){ build(:script) }
  let(:fields){ ['name', 'email', 'address'] }

  subject{ CallFlow::Web::ContactFields::Selected.new(instance) }

  describe 'instantiating' do
    it 'requires a saved Script instance' do
      expect{ 
        CallFlow::Web::ContactFields::Selected.new(invalid_instance)
      }.to raise_error(ArgumentError)
    end
  end

  describe 'adding selected fields' do
    it '#cache(arr) stores given Array as JSON string' do
      subject.cache(fields)
      stored_fields = redis.hget "contact_fields", instance.id
      expect(stored_fields).to eq fields.to_json
    end

    it '#cache_raw(str) stores given String (assumes already JSON)' do
      subject.cache_raw(fields.to_json)
      stored_fields = redis.hget 'contact_fields', instance.id
      expect(stored_fields).to eq fields.to_json
    end
  end

  describe 'fetching fields for given object' do
    it 'returns the fields as an Array' do
      subject.cache(fields)
      expect(subject.data).to eq fields
    end

    it 'returns an empty Array when no fields are cached for the given object' do
      expect(subject.data).to eq []
    end
  end
end
