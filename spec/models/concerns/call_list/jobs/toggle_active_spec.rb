require 'rails_helper'

describe 'CallList::Imports::Jobs::ToggleActive' do
  include ListHelpers

  subject{ CallList::Jobs::ToggleActive }

  let(:campaign) do
    create(:power)
  end
  let(:list_one) do
    create(:voter_list, campaign: campaign)
  end
  let(:list_two) do
    create(:voter_list, campaign: campaign)
  end
  let(:households_one) do
    build_household_hashes(1, list_one, false)
  end
  let(:households_two) do
    build_household_hashes(1, list_two, false)
  end
  let(:active_redis_key){ 'dial_queue:1:households:active:111' }
  let(:inactive_redis_key){ 'dial_queue:1:households:inactive:111' }
  let(:parser) do
    double('CallList::Imports::Parser', {
      each_batch: nil
    })
  end

  before do
    import_list(list_one, households_one)
    import_list(list_two, households_two)
    expect(households_one).to be_in_redis_households(campaign.id, 'active')
    expect(households_two).to be_in_redis_households(campaign.id, 'active')
  end
  
  describe 'list was just disabled' do
    before do
      stub_list_parser(parser, active_redis_key, households_one)
      disable_list(list_one)
      subject.perform(list_one.id)
    end

    it 'removes all associated leads from households:active' do
      expect(households_one).to_not be_in_redis_households(campaign.id, 'active')
    end

    it 'adds all associated leads to households:inactive' do
      expect(households_one).to be_in_redis_households(campaign.id, 'inactive')
    end

    it 'does not remove leads from other lists' do
      expect(households_two).to be_in_redis_households(campaign.id, 'active')
    end
  end

  describe 'list was just enabled' do
    before do
      stub_list_parser(parser, active_redis_key, households_two)
      disable_list(list_two)
      subject.perform(list_two.id)
      expect(households_two).to_not be_in_redis_households(campaign.id, 'active')
      expect(households_two).to be_in_redis_households(campaign.id, 'inactive')

      stub_list_parser(parser, active_redis_key, households_one)
      disable_list(list_one)
      subject.perform(list_one.id)
      expect(households_one).to_not be_in_redis_households(campaign.id, 'active')
      expect(households_one).to be_in_redis_households(campaign.id, 'inactive')

      enable_list(list_one)
      subject.perform(list_one.id)
    end

    it 'removes all associated leads from households:inactive' do
      expect(households_one).to_not be_in_redis_households(campaign.id, 'inactive')
    end

    it 'adds all associated leads to households:active' do
      expect(households_one).to be_in_redis_households(campaign.id, 'active')
    end

    it 'does not alter leads from other lists' do
      expect(households_two).to_not be_in_redis_households(campaign.id, 'active')
      expect(households_two).to be_in_redis_households(campaign.id, 'inactive')
    end
  end
end

