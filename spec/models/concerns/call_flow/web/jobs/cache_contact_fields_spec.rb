require 'rails_helper'

describe 'CallFlow::Web::Jobs::CacheContactFields' do
  let(:script) do
    create(:script, {
      voter_fields: ['First name', 'Email', 'Phone', 'Party'].to_json
    })
  end
  subject{ CallFlow::Web::Jobs::CacheContactFields }
  context 'script is active' do
    it 'caches Script#voter_fields' do
      subject.perform(script.id)
      expect(redis.hget('contact_fields', script.id)).to eq script.voter_fields
    end
  end

  context 'script is not active' do
    before do
      subject.perform(script.id)
      script.update_attributes!({active: false})
    end
    it 'deletes cache of Script#voter_fields at contact_fields' do
      subject.perform(script.id)
      expect(redis.hget('contact_fields', script.id)).to be_nil
    end
  end
end
