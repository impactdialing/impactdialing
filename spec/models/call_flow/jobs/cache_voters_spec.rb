require 'spec_helper'

describe 'CacheVoters.perform(voter_ids, enabled)' do
  context 'enabled.to_i > 0' do
    it 'adds voters to dial queue cache'
  end

  context 'enabled.to_i <= 0' do
    it 'removes voters from dial queue cache'
  end
end
