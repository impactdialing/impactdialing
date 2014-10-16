require 'spec_helper'

describe 'CacheBlockedNumbers.perform(record_id, record_type)' do
  context 'record_type == "Account"' do
    it 'caches account-wide numbers'
  end

  context 'record_type == "Campaign"' do
    it 'caches campaign-specific numbers'
  end
end