require 'rails_helper'

describe 'CallList::Imports' do
  let(:voter_list){ create(:voter_list) }

  let(:redis_keys) do
    [
      "key:#{voter_list.campaign_id}:1",
      "key:#{voter_list.campaign_id}:2",
      "key:#{voter_list.campaign_id}:3"
    ]
  end
  let(:parsed_households) do
    {
      '1234567890' => {
        'leads' => [
          {'custom_id' => 123, 'first_name' => 'john1a', 'phone' => '1234567890', 'line_number' => '1'},
          {'custom_id' => 234, 'first_name' => 'lucy', 'phone' => '1234567890', 'line_number' => '2'},
          {'custom_id' => 123, 'first_name' => 'jack1b', 'phone' => '1234567890', 'line_number' => '3'},
          {'first_name' => 'aria', 'phone' => '1234567890'} # will not be saved due to missing custom id
        ],
        'uuid'  => 'hh-uuid-123',
        'score' => Time.now.utc.to_f
      },
      '4567890123' => {
        'leads' => [
          {'custom_id' => 123, 'first_name' => 'john2', 'phone' => '4567890123', 'line_number' => '4'},
          {'custom_id' => 345, 'first_name' => 'sala', 'phone' => '4567890123', 'line_number' => '5'},
          {'custom_id' => 456, 'first_name' => 'nathan', 'phone' => '4567890123', 'line_number' => '6'},
          {'first_name' => 'sensa', 'phone' => '4567890123'} # will not be saved due to missing custom id
        ],
        'uuid'  => 'hh-uuid-234',
        'score' => Time.now.to_f
      }
    }
  end
  let(:parsed_households_update) do
    {
      '1234567890' => {
        'leads' => [
          {'custom_id' => 123, 'first_name' => 'styx', 'phone' => '1234567890', 'line_number' => '1'},
          {'custom_id' => 234, 'first_name' => 'cirrus', 'phone' => '1234567890', 'line_number' => '2'},
          {'first_name' => 'aria', 'phone' => '1234567890'} # will not be saved due to missing custom id
        ],
        'uuid'  => 'hh-uuid-123',
        'score' => Time.now.to_f
      },
      '4567890123' => {
        'leads' => [
          {'custom_id' => 345, 'first_name' => 'raka', 'phone' => '4567890123', 'line_number' => '3'},
          {'custom_id' => 456, 'first_name' => 'dani', 'phone' => '4567890123', 'line_number' => '4'},
          {'first_name' => 'sensa', 'phone' => '4567890123'} # will not be saved due to missing custom id
        ],
        'uuid'  => 'hh-uuid-234',
        'score' => Time.now.to_f
      }
    }
  end
  let(:common_keys) do
    subject.send(:common_redis_keys)
  end
  before do
    allow(voter_list.campaign).to receive(:using_custom_ids?){ true }
  end
  describe 'save' do
    subject{ CallList::Imports.new(voter_list) }
    let(:phone){ parsed_households.keys.first }
    def fetch_saved_household(voter_list, phone)
      stop_index       = ENV['REDIS_PHONE_KEY_INDEX_STOP'].to_i
      key              = "#{voter_list.campaign.dial_queue.households.keys[:active]}:#{phone[0..stop_index]}"
      hkey             = phone[stop_index+1..-1]
      saved_households = redis.hgetall(key)
      JSON.parse(saved_households[hkey])
    end
    it 'saves households & leads at given redis keys' do
      subject.save(redis_keys, parsed_households)
      household = fetch_saved_household(voter_list, phone)

      %w(custom_id first_name phone).each do |field|
        expect(household['leads'][0][field]).to eq parsed_households[phone]['leads'][2][field]
        expect(household['leads'][1][field]).to eq parsed_households[phone]['leads'][1][field]
      end
      expect(household['uuid']).to eq parsed_households[phone]['uuid']
    end

    describe 'updating voter list stats' do
      let(:stats_key){ common_keys[1] }
      let(:custom_id_register_key){ common_keys[9] }

      context 'using custom id' do

        let(:second_voter_list) do
          create(:voter_list, campaign: voter_list.campaign, account: voter_list.account)
        end
        let(:second_subject){ CallList::Imports.new(second_voter_list) }
        let(:second_stats_key){ second_subject.send(:common_redis_keys)[1] }
        let(:campaign_stats_key){ voter_list.campaign.call_list.stats.key }

        before do
          # save first list
          redis.rpush('debug.log', 'saving first subject')
          subject.save(redis_keys, parsed_households)

          # save second list
          redis.rpush('debug.log', 'saving second subject')
          second_subject.save(redis_keys, parsed_households_update)
        end

        context 'first list' do
          it 'redis hash.new_leads = 4' do
            expect(redis.hget(stats_key, 'new_leads')).to eq '4'
          end
          it 'redis hash.updated_leads = 1' do
            # leads w/ same custom id in two households
            expect(redis.hget(stats_key, 'updated_leads')).to eq '1'
          end
          it 'redis hash.new_numbers = 2' do
            expect(redis.hget(stats_key, 'new_numbers')).to eq '2'
          end
          it 'redis hash.pre_existing_numbers = 0' do
            expect(redis.hget(stats_key, 'pre_existing_numbers')).to eq '0'
          end
          it 'increments redis campaign hash.number_sequence' do
            expect(redis.hget(campaign_stats_key, 'number_sequence')).to eq '2'
          end
          it 'increments redis campaign hash.lead_sequence' do
            expect(redis.hget(campaign_stats_key, 'lead_sequence')).to eq '4'
          end
          it 'redis hash.{campaign_id}.custom_ids contains custom ids of all leads in campaign w/ phone as value' do
            phone_one = parsed_households.keys.first
            phone_two = parsed_households.keys.last
            custom_ids = redis.hgetall(custom_id_register_key)
            expect(custom_ids['123']).to eq phone_one
            expect(custom_ids['234']).to eq phone_one
            expect(custom_ids['345']).to eq phone_two
            expect(custom_ids['456']).to eq phone_two
          end
        end

        context 'second list' do
          it 'redis hash.new_leads = 0' do
            expect(redis.hget(second_stats_key, 'new_leads')).to eq '0'
          end
          it 'redis hash.updated_leads = 4' do
            # leads w/ same custom id in two households
            expect(redis.hget(second_stats_key, 'updated_leads')).to eq '4'
          end
          it 'redis hash.new_numbers = 0' do
            expect(redis.hget(second_stats_key, 'new_numbers')).to eq '0'
          end
          it 'redis hash.pre_existing_numbers = 2' do
            expect(redis.hget(second_stats_key, 'pre_existing_numbers')).to eq '2'
          end
          it 'updates lead attributes' do
            parsed_households_update.each do |phone, expected_household|
              expected_household['leads'].reject!{|lead| lead['custom_id'].blank?}
              household = fetch_saved_household second_voter_list, phone
              expected_household['leads'].each do |lead|
                lead['sequence'] = {'123' => 1, '234' => 4, '345' => 2, '456' => 3}[lead['custom_id'].to_s] 
                expect(household['leads']).to include lead
              end
            end
          end
        end
      end
    end

    context 'households/leads have already been saved' do
      before do
        subject.save(redis_keys, parsed_households)
      end

      it 'preserves the UUID for any existing household' do
        existing_household_uuid = fetch_saved_household(voter_list, phone)['uuid']

        subject.save(redis_keys, parsed_households)
        updated_household_uuid = fetch_saved_household(voter_list, phone)['uuid']

        expect(updated_household_uuid).to eq existing_household_uuid
      end

      context 'custom_id (ID) is in use' do
        it 'preserves the UUID for any existing leads' do
          existing_lead_uuid = fetch_saved_household(voter_list, phone)['leads'].first['uuid']

          subject.save(redis_keys, parsed_households)
          updated_lead_uuid = fetch_saved_household(voter_list, phone)['leads'].first['uuid']

          expect(updated_lead_uuid).to eq existing_lead_uuid
        end
      end
    end

    context 'and no leads have been added (only possible when custom id is in use)' do
      let(:completed_key){ common_keys[6] }
      let(:pending_key){ common_keys[0] }
      before do
        parsed_households[phone]['leads'][0].merge!({'custom_id' => 5})
        subject.save(redis_keys, parsed_households)
        redis.zrem(pending_key, phone)
        redis.zadd(completed_key, 2.2, phone)
      end

      it 'is not added to any set' do
        keys  = [
          pending_key,
          common_keys[3],
          common_keys[4],
          common_keys[5]
        ]
        keys.each do |key|
          expect(redis.zscore(key, phone)).to(be_nil, key)
        end
      end

      it 'is left in completed set' do
        expect(redis.zscore(common_keys[6], phone)).to_not be_nil
      end
    end

    it_behaves_like 'any call list import'
  end
end
