require 'rails_helper'

RSpec::Matchers.define :be_in_households do |campaign_id, namespace|
  redis               = Redis.new
  expected_leads      = []
  leads_in_redis      = []

  match do |households|
    households.each do |phone, household|
      expected_leads += household[:leads].map!(&:stringify_keys)
      key = "dial_queue:#{campaign_id}:households:#{namespace}:#{phone[0..-4]}"
      json = redis.hget(key, phone[-3..-1])
      if json.nil?
        next
      end
      _household = JSON.parse(json)
      leads_in_redis += _household['leads']
    end
    expected_leads.all? do |expected_lead|
      leads_in_redis.include?(expected_lead)
    end
  end
  failure_message do |households|
    "expected to find #{expected_leads} in households:#{campaign_id}:#{namespace}\nfound only these #{leads_in_redis}" 
  end
  failure_message_when_negated do |households|
    "expected to not find #{expected_leads} in households:#{campaign_id}:#{namespace}\nfound only these #{leads_in_redis}" 
  end
end

describe 'List::Imports::Jobs::ToggleActive' do
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

  def import_list(list, households)
    List::Imports.new(list).save([active_redis_key], households)
  end

  def disable_list(list)
    list.update_attributes!(enabled: false)
  end

  def enable_list(list)
    list.update_attributes!(enabled: true)
  end

  def setup_parser(household)
    allow(parser).to receive(:parse_file).and_yield([active_redis_key], household, 0, {})
    allow(List::Imports::Parser).to receive(:new){ parser }
  end

  before do
    import_list(list_one, households_one)
    import_list(list_two, households_two)
    expect(households_one).to be_in_households(campaign.id, 'active')
    expect(households_two).to be_in_households(campaign.id, 'active')
  end
  
  describe 'list was just disabled' do
    before do
      setup_parser(households_one)
      disable_list(list_one)
      subject.perform(list_one.id)
    end

    it 'removes all associated leads from households:active' do
      expect(households_one).to_not be_in_households(campaign.id, 'active')
    end

    it 'adds all associated leads to households:inactive' do
      expect(households_one).to be_in_households(campaign.id, 'inactive')
    end

    it 'does not remove leads from other lists' do
      expect(households_two).to be_in_households(campaign.id, 'active')
    end
  end

  describe 'list was just enabled' do
    before do
      setup_parser(households_two)
      disable_list(list_two)
      subject.perform(list_two.id)
      expect(households_two).to_not be_in_households(campaign.id, 'active')
      expect(households_two).to be_in_households(campaign.id, 'inactive')

      setup_parser(households_one)
      disable_list(list_one)
      subject.perform(list_one.id)
      expect(households_one).to_not be_in_households(campaign.id, 'active')
      expect(households_one).to be_in_households(campaign.id, 'inactive')

      enable_list(list_one)
      subject.perform(list_one.id)
    end

    it 'removes all associated leads from households:inactive' do
      expect(households_one).to_not be_in_households(campaign.id, 'inactive')
    end

    it 'adds all associated leads to households:active' do
      expect(households_one).to be_in_households(campaign.id, 'active')
    end

    it 'does not alter leads from other lists' do
      expect(households_two).to_not be_in_households(campaign.id, 'active')
      byebug
      expect(households_two).to be_in_households(campaign.id, 'inactive')
    end

    it 'all associated phone numbers are made available'
  end
end

