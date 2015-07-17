require 'rails_helper'

describe 'List::Imports' do
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
        'leads' => [{'first_name' => 'john'}],
        'uuid' => 'hh-uuid'
      }
    }
  end
  let(:common_keys) do
    subject.send(:common_redis_keys)
  end

  after do
    Redis.new.flushall
  end

  describe 'initialize' do
    subject{ List::Imports.new(voter_list) }

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
      subject{ List::Imports.new(voter_list) }

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
        expect(subject.results[:invalid_numbers]).to eq Set.new
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

      subject{ List::Imports.new(voter_list, 5, results_json) }

      it 'loads previous results instead of defaults' do
        expect(subject.results).to eq expected_recovered_results.stringify_keys
      end
    end
  end

  describe 'parse' do
    subject{ List::Imports.new(voter_list) }
    let(:parser) do
      double('List::Imports::Parser', {
        parse_file: nil
      })
    end
    let(:cursor){ 0 }
    let(:results) do
      {saved_leads: 3, saved_numbers: 2}
    end

    before do
      allow(parser).to receive(:parse_file).and_yield(redis_keys, parsed_households, cursor+3, results)
      allow(List::Imports::Parser).to receive(:new){ parser }
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
    subject{ List::Imports.new(voter_list) }

    let(:phone){ parsed_households.keys.first }

    def fetch_saved_household(phone)
      redis            = Redis.new
      stop_index       = ENV['REDIS_PHONE_KEY_INDEX_STOP'].to_i
      key              = "key:#{voter_list.campaign_id}:#{phone[0..stop_index]}"
      hkey             = phone[stop_index+1..-1]
      saved_households = redis.hgetall(key)
      JSON.parse(saved_households[hkey])
    end

    it 'saves households & leads at given redis keys' do
      subject.save(redis_keys, parsed_households)
      household = fetch_saved_household(phone)

      expect(household['leads']).to eq parsed_households[phone]['leads']
      expect(household['uuid']).to eq parsed_households[phone]['uuid']
    end

    describe 'updating voter list stats' do
      let(:stats_key){ common_keys[1] }

      def redis
        @redis ||= Redis.new
      end

      context 'not using custom id' do
        before do
          subject.save(redis_keys, parsed_households)
        end

        it 'redis hash.new_leads = 1' do
          expect(redis.hget(stats_key, 'new_leads')).to eq '1'
        end
        it 'redis hash.updated_leads = 0' do
          expect(redis.hget(stats_key, 'updated_leads')).to eq '0'
        end
        it 'redis hash.new_numbers = 1' do
          expect(redis.hget(stats_key, 'new_numbers')).to eq '1'
        end
        it 'redis hash.pre_existing_numbers = 0' do
          expect(redis.hget(stats_key, 'pre_existing_numbers')).to eq '0'
        end
      end

      context 'using custom id' do
        let(:parsed_households) do
          {
            '1234567890' => {
              'leads' => [
                {'custom_id' => 123, 'first_name' => 'john'},
                {'custom_id' => 234, 'first_name' => 'lucy'},
                {'custom_id' => 123, 'first_name' => 'jack'}
              ],
              'uuid'  => 'hh-uuid-123'
            },
            '4567890123' => {
              'leads' => [
                {'custom_id' => 345, 'first_name' => 'sala'},
                {'custom_id' => 456, 'first_name' => 'nathan'}
              ],
              'uuid'  => 'hh-uuid-234'
            }
          }
        end

        let(:second_voter_list) do
          create(:voter_list, campaign: voter_list.campaign, account: voter_list.account)
        end
        let(:second_subject){ List::Imports.new(second_voter_list) }
        let(:second_stats_key){ second_subject.send(:common_redis_keys)[1] }

        before do
          # save first list
          subject.save(redis_keys, parsed_households)

          # save second list
          second_subject.save(redis_keys, parsed_households)
        end

        context 'first list' do
          it 'redis hash.new_leads = 4' do
            expect(redis.hget(stats_key, 'new_leads')).to eq '4'
          end
          it 'redis hash.updated_leads = 0' do
            expect(redis.hget(stats_key, 'updated_leads')).to eq '0'
          end
          it 'redis hash.new_numbers = 2' do
            expect(redis.hget(stats_key, 'new_numbers')).to eq '2'
          end
          it 'redis hash.pre_existing_numbers = 0' do
            expect(redis.hget(stats_key, 'pre_existing_numbers')).to eq '0'
          end
        end

        context 'second list' do
          it 'redis hash.new_leads = 0' do
            expect(redis.hget(second_stats_key, 'new_leads')).to eq '0'
          end
          it 'redis hash.updated_leads = 4' do
            expect(redis.hget(second_stats_key, 'updated_leads')).to eq '4'
          end
          it 'redis hash.new_numbers = 0' do
            expect(redis.hget(second_stats_key, 'new_numbers')).to eq '0'
          end
          it 'redis hash.pre_existing_numbers = 2' do
            expect(redis.hget(second_stats_key, 'pre_existing_numbers')).to eq '2'
          end
        end
      end
    end

    context 'households/leads have already been saved' do
      before do
        subject.save(redis_keys, parsed_households)
      end

      it 'preserves the UUID for any existing household' do
        existing_household_uuid = fetch_saved_household(phone)['uuid']

        subject.save(redis_keys, parsed_households)
        updated_household_uuid = fetch_saved_household(phone)['uuid']

        expect(updated_household_uuid).to eq existing_household_uuid
      end

      context 'custom_id (ID) is in use' do
        it 'preserves the UUID for any existing leads' do
          existing_lead_uuid = fetch_saved_household(phone)['leads'].first['uuid']

          subject.save(redis_keys, parsed_households)
          updated_lead_uuid = fetch_saved_household(phone)['leads'].first['uuid']

          expect(updated_lead_uuid).to eq existing_lead_uuid
        end
      end
    end

    describe 'adding numbers to zsets' do
      context 'number is blocked' do
        before do
          parsed_households[phone].merge!({'blocked' => 1})
        end

        it 'adds to blocked zset' do
          subject.save(redis_keys, parsed_households)
          blocked_key = common_keys[5]
          expect(redis.zscore(blocked_key, phone)).to eq 1.0
        end

        it 'removes from available zset' do
          available_key = common_keys[3]
          redis.zadd available_key, 1.0, phone
          subject.save(redis_keys, parsed_households)
          expect(redis.zscore(available_key, phone)).to be_nil
        end

        it 'removes from recycle bin zset' do
          recycle_key = common_keys[4]
          redis.zadd recycle_key, 1.0, phone
          subject.save(redis_keys, parsed_households)
          expect(redis.zscore(recycle_key, phone)).to be_nil
        end
      end

      context 'number is not blocked' do
        before do
          parsed_households[phone].merge!({'blocked' => 0})
        end

        context 'number is not completed' do
          it 'adds to pending zset' do
            pending_key = common_keys[0]
            subject.save(redis_keys, parsed_households)
            expect(redis.zscore(pending_key, phone)).to_not be_nil
          end
        end

        context 'number is completed' do
          let(:completed_key){ common_keys[6] }
          let(:pending_key){ common_keys[0] }

          before do
            parsed_households[phone]['leads'][0].merge!({'custom_id' => 5})
            subject.save(redis_keys, parsed_households)
            redis.zrem(pending_key, phone)
            redis.zadd(completed_key, 2.2, phone)
          end

          context 'and no leads have been added (only possible when custom id is in use)' do
            before do
              subject.save(redis_keys, parsed_households)
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

          context 'and 1 or more leads have been added' do
            before do
              parsed_households[phone]['leads'] << {
                'custom_id'  => 6,
                'first_name' => 'Marion'
              }
              subject.save(redis_keys, parsed_households)
            end

            it 'is removed from completed set' do
              expect(redis.zscore(common_keys[6], phone)).to be_nil
            end

            it 'is added to pending set' do
              expect(redis.zscore(common_keys[0], phone)).to_not be_nil
            end
          end
        end
      end
    end
  end
end
