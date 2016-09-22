require 'rails_helper'

describe 'CallList::Imports' do
  let(:voter_list) do
    create(:voter_list, {
      csv_to_system_map: {
        'ID' => 'custom_id',
        'Phone' => 'phone',
        'DISTRICT' => 'District',
        'POLLING LOC' => 'Polling location'
      }
    })
  end

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
        'leads' => [{'first_name' => 'john', 'Polling location' => 'Albany', 'District' => '1A', 'sequence' => '1', 'line_number' => '1'}],
        'uuid' => 'hh-uuid',
        'score' => Time.now.utc.to_f
      }
    }
  end
  let(:common_keys) do
    subject.send(:common_redis_keys)
  end

  describe 'importing CustomVoterFields to SQL backend' do
    subject{ CallList::Imports.new(voter_list) }

    it 'creates a new CustomVoterField record for each user-defined field' do
      expect{ subject.create_new_custom_voter_fields! }.to change{ CustomVoterField.count }.by 2
    end

    it 'each CustomVoterField record is associated w/ the account of the admin who uploaded the list' do
      subject.create_new_custom_voter_fields!
      expect(voter_list.account.custom_voter_fields.count).to eq 2
    end

    it 'does not create records if matching field exists' do
      subject.create_new_custom_voter_fields!
      expect{ subject.create_new_custom_voter_fields! }.to change{ CustomVoterField.count }.by 0
    end
  end

  describe 'initialize' do
    subject{ CallList::Imports.new(voter_list) }

    it 'exposes voter_list instance' do
      expect(subject.voter_list).to eq voter_list
    end
    it 'exposes cursor int' do
      expect(subject.cursor).to eq 0
    end
    it 'exposes results hash' do
      expect(subject.results).to be_kind_of Hash
    end

    context 'default @results hash' do
      subject{ CallList::Imports.new(voter_list) }

      it 'saved_numbers => 0' do
        expect(subject.results[:saved_numbers]).to be_zero
      end
      it 'total_numbers => 0' do
        expect(subject.results[:total_numbers]).to be_zero
      end
      it 'saved_leads => 0' do
        expect(subject.results[:saved_leads]).to be_zero
      end
      it 'total_leads => 0' do
        expect(subject.results[:total_leads]).to be_zero
      end
      it 'new_numbers => Set.new' do
        expect(subject.results[:new_numbers]).to be_zero
      end
      it 'pre_existing_numbers => Set.new' do
        expect(subject.results[:pre_existing_numbers]).to be_zero
      end
      it 'dnc_numbers => Set.new' do
        expect(subject.results[:dnc_numbers]).to eq Set.new
      end
      it 'cell_numbers => Set.new' do
        expect(subject.results[:cell_numbers]).to eq Set.new
      end
      it 'new_leads => 0' do
        expect(subject.results[:total_leads]).to be_zero
      end
      it 'updated_leads => 0' do
        expect(subject.results[:updated_leads]).to be_zero
      end
      it 'invalid_numbers => Set.new' do
        expect(subject.results[:invalid_numbers]).to eq []
      end
      it 'invalid_rows => []' do
        expect(subject.results[:invalid_rows]).to eq []
      end
      it 'use_custom_id => false' do
        expect(subject.results[:use_custom_id]).to be_falsey
      end
    end

    context 'recover results from encoded string to initialize' do
      let(:expected_recovered_results) do
        {
          saved_numbers:        3,
          total_numbers:        10,
          saved_leads:          2,
          total_leads:          10,
          new_leads:            1,
          updated_leads:        1,
          new_numbers:          2,
          pre_existing_numbers: 2,
          dnc_numbers:          Set.new,
          cell_numbers:         Set.new,
          invalid_numbers:      Set.new(['123','456']),
          invalid_rows:         [["123,Sam,McGee"],["456,Jasmine,Songbird"]],
          use_custom_id:        false
        }
      end
      let(:results_json){ expected_recovered_results.to_json }

      subject{ CallList::Imports.new(voter_list, 5, results_json) }

      it 'loads previous results instead of defaults' do
        expect(subject.results).to eq expected_recovered_results.stringify_keys
      end
    end
  end

  describe 'parse' do
    subject{ CallList::Imports.new(voter_list) }
    let(:parser) do
      double('CallList::Imports::Parser', {
        each_batch: nil
      })
    end
    let(:cursor){ 0 }
    let(:results) do
      {saved_leads: 3, saved_numbers: 2}
    end

    before do
      allow(parser).to receive(:each_batch).and_yield(redis_keys, parsed_households, cursor+3, results)
      allow(CallList::Imports::Parser).to receive(:new){ parser }
    end

    it 'yields array of redis keys as first arg and hash of households as second arg' do
      expect{|b| subject.parse(&b)}.to yield_with_args(Array, Hash)
    end

    it 'updates @cursor' do
      subject.parse{|keys, households| nil}
      expect(subject.cursor).to be > 0
    end

    it 'updates @results' do
      subject.parse{|keys, households| nil}
      expect(subject.results).to_not eq subject.send(:default_results)
    end
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

    it_behaves_like 'any call list import'

    it 'saves households & leads at given redis keys' do
      subject.save(redis_keys, parsed_households)
      household = fetch_saved_household(voter_list, phone)

      expect(household['leads']).to eq parsed_households[phone]['leads']
      expect(household['uuid']).to eq parsed_households[phone]['uuid']
    end

    describe 'updating voter list stats' do
      let(:stats_key){ common_keys[1] }
      let(:custom_id_register_key){ common_keys[7] }

      context 'not using custom id' do
        before do
          subject.save(redis_keys, parsed_households)
        end

        it 'redis hash.new_leads = 1' do
          expect(redis.hget(stats_key, 'new_leads')).to eq '1'
        end
        it 'redis hash.new_numbers = 1' do
          expect(redis.hget(stats_key, 'new_numbers')).to eq '1'
        end
        it 'redis hash.pre_existing_numbers = 0' do
          expect(redis.hget(stats_key, 'pre_existing_numbers')).to eq '0'
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
    end
  end
end
