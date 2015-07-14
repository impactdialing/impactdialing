require 'rails_helper'

RSpec::Matchers.define :be_in_redis do
  redis = Redis.new
  match do |households|
    expected_leads = []
    leads_in_redis = []

    households.each do |phone, household|
      expected_leads += household[:leads].map!(&:stringify_keys)
      json = redis.hget("key:1:ns:#{phone[0..-4]}", phone[-3..-1])
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
      '1234567890' => {leads: [{voter_list_id: list_one.id, first_name: 'John', last_name: 'Doe'}]},
      '4567890123' => {leads: [{voter_list_id: list_one.id, first_name: 'Sally', last_name: 'Dugget'}]}
    }
  end
  let(:households_two) do
    {
      '1234567890' => {leads: [{voter_list_id: list_two.id, first_name: 'George', last_name: 'Jungle'}]},
      '0456789123' => {leads: [{voter_list_id: list_two.id, first_name: 'Kristin', last_name: 'Hops'}]}
    }
  end
  let(:redis_key){ 'key:1:ns:1234567' }
  let(:parser) do
    double('List::Imports::Parser', {
      parse_file: nil
    })
  end

  def import_list(list, households)
    List::Imports.new(list).save([redis_key], households)
  end

  def disable_list(list)
    list.update_attributes!(enabled: false)
    subject.perform(list.id, list.enabled)
  end

  before do
    allow(parser).to receive(:parse_file).and_yield([redis_key], households_one, 0, {})
    allow(List::Imports::Parser).to receive(:new){ parser }
    import_list(list_one, households_one)
    import_list(list_two, households_two)
    expect(households_one).to be_in_redis
    expect(households_two).to be_in_redis
  end
  
  describe 'list was just disabled' do
    before do
      disable_list(list_one)
    end

    it 'removes all associated leads from redis' do
      expect(households_one).to_not be_in_redis
    end

    it 'does not remove leads from other lists' do
      expect(households_two).to be_in_redis
    end
  end

  describe 'list was just enabled' do
    before do
      disable_list(list_one)
    end

    it 'imports all associated leads to redis' do
      expect(List::Jobs::Import).to receive(:perform).with(list_one.id)
      list_one.update_attributes!(enabled: true)
      subject.perform(list_one.id, true)
    end
  end
end

