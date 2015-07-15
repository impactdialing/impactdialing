require 'rails_helper'

describe 'List::Imports::Jobs::ToggleActive' do
  include ListHelpers

  subject{ List::Jobs::ToggleActive }

  after do
    Redis.new.flushall
  end

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
    {
      '1234567890' => {
        leads: [{voter_list_id: list_one.id, first_name: 'John', last_name: 'Doe'}]
      },
      '4567890123' => {
        leads: [{voter_list_id: list_one.id, first_name: 'Sally', last_name: 'Dugget'}]
      }
    }
  end
  let(:households_two) do
    {
      '1234567890' => {
        leads: [{voter_list_id: list_two.id, first_name: 'George', last_name: 'Jungle'}]
      },
      '0456789123' => {
        leads: [{voter_list_id: list_two.id, first_name: 'Kristin', last_name: 'Hops'}]
      }
    }
  end
  let(:active_redis_key){ 'dial_queue:1:households:active:111' }
  let(:inactive_redis_key){ 'dial_queue:1:households:inactive:111' }
  let(:parser) do
    double('List::Imports::Parser', {
      parse_file: nil
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

