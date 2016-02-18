require 'rails_helper'

describe 'CallFlow::DialQueue::Households' do
  include ListHelpers

  let(:campaign){ create(:power) }
  let(:voter_list){ create(:voter_list, campaign: campaign) }
  let(:households) do
    build_household_hashes(10, voter_list, false, true)
  end

  subject{ CallFlow::DialQueue::Households.new(campaign) }

  def key(phone)
    subject.send(:hkey, phone)
  end

  before do
    import_list(voter_list, households)
  end

  describe 'purge!(phones)' do
    it 'deletes all households and meta-data' do
      subject.purge!
      remaining_keys = redis.scan_each(match: "dial_queue:#{campaign.id}:households*").to_a
      expect(remaining_keys).to be_empty
    end
  end

  describe 'finding presentable households' do
    let(:phone) do
      households.keys.first
    end
    let(:phones) do
      households.keys[0..5]
    end
    let(:household_collection) do
      households.values
    end

    it 'returns a collection of households given a set of phone numbers' do
      expect(subject.find_presentable(phone).first[:leads]).to match household_collection.first[:leads]

      subject.find_presentable(phones).each_with_index do |house, i|
        expect(house[:leads]).to match household_collection[i][:leads]
      end
    end

    it 'saves a copy of each returned household to the :presented namespace' do
      subject.find_presentable(phones)

      presented_households = CallFlow::DialQueue::Households.new(campaign, :presented)
      phones.each do |phone|
        expect(presented_households.find(phone)[:leads]).to match households[phone][:leads]
      end
    end

    it 'does not include completed leads in returned households' do
      completed_lead_key = subject.send(:keys)[:completed_leads]
      redis.setbit(completed_lead_key, households[phone][:leads].first['sequence'], 1)
      expect(subject.find_presentable(phone).first[:leads]).to_not include households[phone][:leads].first
    end

    it 'returns empty result if nothing is in redis for active_key/hkey' do
      hkey = subject.send(:hkey, phone)
      redis.hdel *hkey
      expect(subject.find_presentable(phone)).to be_blank
    end

    it 'returns empty result if no available (ie incomplete) leads are in household' do
      hkey  = subject.send(:hkey, phone)
      house = JSON.parse redis.hget(*hkey)
      house['leads'].each do |lead|
        subject.mark_lead_completed(lead['sequence'])
      end
      redis.hset(*hkey, house.to_json)
      expect(subject.find_presentable(phone)).to be_blank
    end
  end

  describe 'auto selecting best available lead for disposition from target household' do
    let(:phone){ households.keys.first }
    let(:first_lead){ households[phone][:leads].sort_by{|lead| lead['sequence']}.first }
    let(:second_lead){ households[phone][:leads].sort_by{|lead| lead['sequence']}[1] } 

    context 'no leads have been dispositioned' do
      before do
        subject.find_presentable(phone)
      end
      it 'returns the lead w/ the lowest sequence first' do
        expect(subject.auto_select_lead_for_disposition(phone)).to match first_lead 
      end
    end

    context '1 lead has been dispositioned but is not complete' do
      before do
        subject.mark_lead_dispositioned(first_lead['sequence'])
        subject.find_presentable(phone)
      end

      it 'returns the lead that has not been dispositioned first' do
        expect(subject.auto_select_lead_for_disposition(phone)).to match second_lead
      end
    end

    context 'all leads have been dispositioned but only the second is completed' do
      before do
        households[phone][:leads].each do |lead|
          subject.mark_lead_dispositioned(lead['sequence'])
        end
        subject.mark_lead_completed(second_lead['sequence'])
        subject.find_presentable(phone)
      end
      it 'returns the lead w/ the lowest sequence first' do
        expect(subject.auto_select_lead_for_disposition(phone)).to match first_lead
      end
    end
  end

  describe 'automatic message drops' do
    let(:redis_key){ "dial_queue:#{campaign.id}:households:message_drops" }
    let(:phone_one){ households.keys.last }
    let(:sequence_one){ households[phone_one]['sequence'] }

    before do
      subject.record_message_drop(sequence_one)
    end

    describe 'record when a message has been dropped' do
      context 'for a given sequence' do
        it 'sets bit to 1 for given household sequence' do
          expect(redis.getbit(redis_key, sequence_one)).to eq 1
        end
      end
      context 'for a given phone number' do
        let(:phone_two){ households.keys.first }
        let(:sequence_two){ households[phone_two]['sequence'] }

        it 'sets bit to 1 for household sequence of given phone number' do
          subject.record_message_drop_by_phone(phone_two)
          expect(redis.getbit(redis_key, sequence_two)).to eq 1
        end
      end
    end

    describe 'detect if a message has been dropped' do
      context 'for a given sequence' do
        let(:sequence_two){ households[households.keys.first]['sequence'] }

        it 'returns true when bit for household sequence is 1' do
          expect(subject.message_dropped_recorded?(sequence_two)).to be_falsey
        end
        it 'returns false when bit for household sequence is 0' do
          expect(subject.message_dropped_recorded?(sequence_one)).to be_truthy
        end
      end

      context 'for a given phone number' do
        let(:phone_two){ households.keys.first }

        it 'returns true when bit for household sequence is 1' do
          expect(subject.message_dropped?(phone_one)).to be_truthy
        end
        it 'returns false when bit for household sequence is 0' do
          expect(subject.message_dropped?(phone_two)).to be_falsey
        end
      end
    end
  end

  describe 'existence' do
    it 'returns true when any households exist' do
      expect(subject.exists?).to be_truthy
    end

    it 'returns false otherwise' do
      redis.flushdb
      expect(subject.exists?).to be_falsey
    end
  end

  describe 'finding data for given phone number(s)' do
    let(:phone_one){ households.keys.first }
    let(:phone_two){ households.keys.last }
    let(:household_one){ HashWithIndifferentAccess.new(households[phone_one]) }
    let(:household_two){ HashWithIndifferentAccess.new(households[phone_two]) }

    describe 'finding a collection of members ids for a given phone number' do
      context 'the redis-key & hash-key of the phone number exist' do
        it 'return an array of members' do
          leads_one = subject.find(phone_one)[:leads]
          leads_two = subject.find(phone_two)[:leads]
          expect(leads_one).to eq household_one[:leads]
          expect(leads_two).to eq household_two[:leads]
        end
      end

      context 'the redis-key & hash-key of the phone number do not exist' do
        it 'return {}' do
          actual = subject.find('1234567890')

          expect(actual).to eq({})
        end
      end
    end

    describe 'finding one or more collections of member ids for one or more given phone numbers' do
      it 'return a hash where phone numbers are keys with each value a collection of member ids eg {"5554442211" => ["35","42"]}' do
        actual = subject.find_all([phone_one, phone_two])
        expected = {
          phone_one => household_one,
          phone_two => household_two
        }
        expect(actual).to eq expected
      end
    end

    describe '#find_grouped_leads(phone, group_by)' do
      it 'returns a hash' do
        actual = subject.find_grouped_leads(phone_one)
        expect(actual).to be_kind_of Hash
      end

      describe 'the hash' do
        it 'keys are values of lead attr given by group_by (uuid by default)' do
          household = subject.find(phone_one)
          uuids = household[:leads].map{|l| l[:uuid]}
          actual = subject.find_grouped_leads(phone_one)
          expect(actual.keys).to eq uuids
        end

        it 'values are array of leads' do
          household = subject.find(phone_one)
          actual = subject.find_grouped_leads(phone_one)
          expect(actual.values).to eq household[:leads].map{|l| [l]}
        end
      end
    end
  end

  describe 'updating leads w/ persisted Voter SQL IDs' do
    let(:phone){ households.keys.first }
    let(:redis_household){ redis.hgetall("dial_queue:#{campaign.id}:households:active:#{phone[0..-4]}") }
    let(:redis_leads){ JSON.parse(redis_household[phone[-3..-1]])['leads'] }
    let(:household_record) do
      Household.create!({
        phone: phone,
        status: CallAttempt::Status::BUSY,
        campaign: campaign,
        account: campaign.account
      })
    end
    let(:uuid_to_id_map) do
      {}
    end

    before do
      redis_leads.each do |lead|
        attrs = {
          campaign_id: campaign.id,
          account_id: campaign.account_id,
          household_id: household_record.id
        }
        lead.each do |prop,val|
          attrs[prop] = val if prop != 'id' and Voter.column_names.include?(prop)
        end
        voter_record                = Voter.create!(attrs)
        uuid_to_id_map[lead[:uuid]] = voter_record.id
      end

      subject.update_leads_with_sql_ids(phone, uuid_to_id_map)
    end

    it 'stores Voter SQL ID with redis lead data' do
      redis_leads.each do |lead|
        expect(lead['sql_id']).to eq uuid_to_id_map[lead['uuid']]
      end
    end
  end

  describe 'marking leads completed' do
    let(:redis_key){ "dial_queue:#{campaign.id}:households:completed_leads" }
    let(:phone){ households.keys.last }
    let(:redis_household){ redis.hgetall("dial_queue:#{campaign.id}:households:active:#{phone[0..-4]}") }
    let(:redis_leads){ JSON.parse(redis_household[phone[-3..-1]])['leads'] }
    let(:sequence){ redis_leads.first['sequence'] }
    
    before do
      expect(sequence).to be > 0
    end

    describe '#mark_lead_completed' do
      it 'sets bitmap to 1 for given lead.sequence' do
        subject.mark_lead_completed(sequence)
        expect(redis.getbit(redis_key, sequence)).to eq 1
      end
    end

    describe '#lead_completed?' do
      before do
        subject.mark_lead_completed(sequence)
      end
      it 'returns true when lead is marked completed' do
        expect(subject.lead_completed?(sequence)).to be_truthy
      end

      it 'returns false when lead is not marked completed' do
        expect(subject.lead_completed?(sequence+1)).to be_falsey
      end
    end

    describe '#any_incomplete_leads_for?(phone)' do
      it 'returns true when 1 or more leads is not marked completed in household' do
        expect(subject.any_incomplete_leads_for?(phone)).to be_truthy
      end

      it 'returns false when all leads are marked completed in household' do
        redis_leads.each do |lead|
          subject.mark_lead_completed(lead['sequence'])
        end
        expect(subject.any_incomplete_leads_for?(phone)).to be_falsey
      end
    end
  end

  describe 'determine if phone should be dialed again' do
    let(:phone){ households.keys.first }
    let(:redis_household){ redis.hgetall("dial_queue:#{campaign.id}:households:active:#{phone[0..-4]}") }
    let(:redis_leads){ JSON.parse(redis_household[phone[-3..-1]])['leads'] }

    context 'all leads have been completed' do
      before do
        redis_leads.each do |lead|
          subject.mark_lead_completed(lead['sequence'])
        end
      end

      it 'returns false' do
        expect(subject.dial_again?(phone)).to be_falsey
      end
    end

    context 'Answering Machine Detection is set to drop messages automatically' do
      before do
        campaign.update_attributes!({
          use_recordings: true,
          answering_machine_detect: true
        })
      end
      context 'Campaign calls back after voicemail delivery' do
        before do
          campaign.update_attributes!({
            call_back_after_voicemail_delivery: true
          })
        end
        it 'returns true when no message has been dropped' do
          expect(subject.dial_again?(phone)).to be_truthy
        end
        it 'returns true when a message has been dropped' do
          expect(subject.dial_again?(phone)).to be_truthy
        end
      end

      context 'Campaign does not call back after voicemail delivery' do
        it 'returns true when no message has been dropped' do
          expect(subject.dial_again?(phone)).to be_truthy
        end
        it 'returns false when a message has been dropped' do
          subject.record_message_drop_by_phone(phone)
          expect(subject.dial_again?(phone)).to be_falsey
        end
      end
    end
  end
end

