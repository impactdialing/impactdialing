require 'rails_helper'
require 'migrate_redis'

describe 'MigrateRedis' do
  include FakeCallData if defined?(FakeCallData) 

  let(:campaign){ create(:power) }
  let(:redis){ Redis.new }

  def hh_key(phone, namespace='active')
    "dial_queue:#{campaign.id}:households:#{namespace}:#{phone[0..-4]}"
  end

  def hh_props
    %w(blocked phone uuid campaign_id account_id sequence sql_id)
  end

  def voter_props
    %w(phone uuid campaign_id account_id sequence sql_id)
  end

  subject{ MigrateRedis.new(campaign) }

  context 'active households' do
    let(:voters) do
      add_voters(campaign, :voter_with_custom_id, 25)
    end
    let(:households){ voters.map(&:household).uniq }
    let(:household){ households.first }
    let(:phone){ household.phone }
    let(:hh) do
      JSON.parse(redis.hget(hh_key(phone), phone[-3..-1]))
    end
    it 'updates active redis households' do
      subject.import(household)
      hh_props.each do |prop|
        expect(hh[prop]).to be_present
      end
      hh['leads'].each do |lead|
        voter_props.each do |prop|
          expect(lead[prop]).to be_present
        end
      end

      expect(hh['leads'].size).to eq household.voters.count
    end

    it 'registers custom ids' do
      subject.import(household)
      key = "list:#{campaign.id}:custom_ids"
      hh['leads'].each do |lead|
        registered_phone = redis.hget key, lead['custom_id']
        expect(registered_phone).to eq phone
      end
    end

    it 'sets dispositioned bit' do
      create(:answer, {
        voter: household.voters.first
      })
      subject.import(household)
      key = "dial_queue:#{campaign.id}:households:dispositioned_leads"
      lead = hh['leads'].detect{|lead| lead['sql_id'].to_i == household.voters.first.id}
      expect(redis.getbit(key, lead['sequence'])).to eq 1
    end
    it 'sets completed bit' do
      create(:answer, {
        voter: household.voters.first
      })
      subject.import(household)
      key = "dial_queue:#{campaign.id}:households:completed_leads"
      lead = hh['leads'].detect{|lead| lead['sql_id'].to_i == household.voters.first.id}
      expect(redis.getbit(key, lead['sequence'])).to eq 1
    end
    it 'sets message drop bit' do
      create(:call_attempt, {
        recording_id: 42,
        household: household
      })
      subject.import(household)
      key = "dial_queue:#{campaign.id}:households:message_drops"
      lead = hh['leads'].detect{|lead| lead['sql_id'].to_i == household.voters.first.id}
      expect(redis.getbit(key, lead['sequence'])).to eq 1
    end
    it 'updates not called scores to match sequence' do
      subject.import(household)
      key = "dial_queue:#{campaign.id}:active"
      score = redis.zscore(key, household.phone)
      expect(score).to be_within(0.1).of hh['sequence'].to_f
    end
    it 'adds blocked phones to blocked zset' do
      household.update_attributes!(blocked: :dnc)
      subject.import(household)
      key = "dial_queue:#{campaign.id}:blocked"
      score = redis.zscore key, household.phone
      expect(score).to be_present
    end
    it 'updates voter list stats: total_numbers, total_leads' do
      subject.import(household)
      key = "list:voter_list:#{household.voters.first.voter_list_id}:stats"
      stats = redis.hgetall key
      expect(stats['total_numbers']).to eq "1"
      expect(stats['total_leads']).to eq household.voters.count.to_s
    end
    it 'updates campaign stats: total_numbers, total_leads' do
      subject.import(household)
      key = "list:campaign:#{household.voters.first.voter_list_id}:stats"
      stats = redis.hgetall key
      expect(stats['total_numbers']).to eq "1"
      expect(stats['total_leads']).to eq household.voters.count.to_s
    end
  end

  context 'enabled but inactive households (completed, failed or blocked)' do
    let(:voters) do
      create_list(:voter_with_custom_id, 25, enabled: :list)
    end
    let(:households){ voters.map(&:household).uniq }
    let(:household){ households.first }
    let(:phone){ household.phone }
    let(:hh){ JSON.parse(redis.hget(hh_key(phone, 'active'), phone[-3..-1])) }

    it 'updates inactive redis households' do
      subject.import(household)
      hh_props.each do |prop|
        expect(hh[prop]).to be_present
      end
      hh['leads'].each do |lead|
        voter_props.each do |prop|
          expect(lead[prop]).to be_present
        end
      end

      expect(hh['leads'].size).to eq household.voters.count
    end
    it 'registers custom ids' do
      subject.import(household)
      key = "list:#{campaign.id}:custom_ids"
      hh['leads'].each do |lead|
        registered_phone = redis.hget key, lead['custom_id']
        expect(registered_phone).to eq phone
      end
    end

    it 'sets dispositioned bit' do
      create(:answer, {
        voter: household.voters.first
      })
      subject.import(household)
      key = "dial_queue:#{campaign.id}:households:dispositioned_leads"
      lead = hh['leads'].detect{|lead| lead['sql_id'].to_i == household.voters.first.id}
      expect(redis.getbit(key, lead['sequence'])).to eq 1
    end
    it 'sets completed bit' do
      create(:answer, {
        voter: household.voters.first
      })
      subject.import(household)
      key = "dial_queue:#{campaign.id}:households:completed_leads"
      lead = hh['leads'].detect{|lead| lead['sql_id'].to_i == household.voters.first.id}
      expect(redis.getbit(key, lead['sequence'])).to eq 1
    end
    it 'sets message drop bit' do
      create(:call_attempt, {
        recording_id: 42,
        household: household
      })
      subject.import(household)
      key = "dial_queue:#{campaign.id}:households:message_drops"
      lead = hh['leads'].detect{|lead| lead['sql_id'].to_i == household.voters.first.id}
      expect(redis.getbit(key, lead['sequence'])).to eq 1
    end
    it 'updates not called scores to match sequence' do
      subject.import(household)
      expect(hh['score'].to_f).to be_within(0.1).of hh['sequence'].to_f
    end
    it 'adds blocked phones to blocked zset' do
      household.update_attributes!(blocked: :dnc)
      subject.import(household)
      key = "dial_queue:#{campaign.id}:blocked"
      score = redis.zscore key, household.phone
      expect(score).to be_present
    end
    it 'adds completed phones to completed zset' do
      create(:call_attempt, {household: household})
      allow(household).to receive(:complete?){ true }
      subject.import(household)
      key = "dial_queue:#{campaign.id}:completed"
      score = redis.zscore key, household.phone
      expect(score).to be_present
    end
    it 'adds failed phones to failed zset' do
      allow(household).to receive(:complete?){ false }
      allow(household).to receive(:failed?){ true }
      subject.import(household)
      key = "dial_queue:#{campaign.id}:failed"
      score = redis.zscore key, household.phone
      expect(score).to be_present
    end
  end
  context 'disabled households' do
    let(:voters) do
      create_list(:voter_with_custom_id, 25, enabled: false)
    end
    let(:households){ voters.map(&:household).uniq }
    let(:household){ households.first }
    let(:phone){ household.phone }
    let(:hh){ JSON.parse(redis.hget(hh_key(phone, 'inactive'), phone[-3..-1])) }

    it 'updates inactive redis households' do
      subject.import(household)
      hh_props.each do |prop|
        expect(hh[prop]).to be_present
      end
      hh['leads'].each do |lead|
        voter_props.each do |prop|
          expect(lead[prop]).to be_present
        end
      end

      expect(hh['leads'].size).to eq household.voters.count
    end
    it 'registers custom ids' do
      subject.import(household)
      key = "list:#{campaign.id}:custom_ids"
      hh['leads'].each do |lead|
        registered_phone = redis.hget key, lead['custom_id']
        expect(registered_phone).to eq phone
      end
    end

    it 'sets dispositioned bit' do
      create(:answer, {
        voter: household.voters.first
      })
      subject.import(household)
      key = "dial_queue:#{campaign.id}:households:dispositioned_leads"
      lead = hh['leads'].detect{|lead| lead['sql_id'].to_i == household.voters.first.id}
      expect(redis.getbit(key, lead['sequence'])).to eq 1
    end
    it 'sets completed bit' do
      create(:answer, {
        voter: household.voters.first
      })
      subject.import(household)
      key = "dial_queue:#{campaign.id}:households:completed_leads"
      lead = hh['leads'].detect{|lead| lead['sql_id'].to_i == household.voters.first.id}
      expect(redis.getbit(key, lead['sequence'])).to eq 1
    end
    it 'sets message drop bit' do
      create(:call_attempt, {
        recording_id: 42,
        household: household
      })
      subject.import(household)
      key = "dial_queue:#{campaign.id}:households:message_drops"
      lead = hh['leads'].detect{|lead| lead['sql_id'].to_i == household.voters.first.id}
      expect(redis.getbit(key, lead['sequence'])).to eq 1
    end
    it 'updates not called scores to match sequence' do
      subject.import(household)
      expect(hh['score'].to_f).to be_within(0.1).of hh['sequence'].to_f
    end
    it 'adds blocked phones to blocked zset' do
      household.update_attributes!(blocked: :dnc)
      subject.import(household)
      key = "dial_queue:#{campaign.id}:blocked"
      score = redis.zscore key, household.phone
      expect(score).to be_present
    end
    it 'adds completed phones to completed zset' do
      allow(household).to receive(:complete?){ true }
      subject.import(household)
      key = "dial_queue:#{campaign.id}:completed"
      score = redis.zscore key, household.phone
      expect(score).to be_present
    end
    it 'adds failed phones to failed zset' do
      allow(household).to receive(:complete?){ false }
      allow(household).to receive(:failed?){ true }
      subject.import(household)
      key = "dial_queue:#{campaign.id}:failed"
      score = redis.zscore key, household.phone
      expect(score).to be_present
    end
  end
end

