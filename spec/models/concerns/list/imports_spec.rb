require 'rails_helper'

describe 'List::Imports' do
  let(:voter_list){ create(:voter_list) }

  let(:redis_keys){ ['key:1', 'key:2', 'key:3'] }
  let(:parsed_households) do
    {
      '1234567890' => {
        'leads' => [{'first_name' => 'john'}],
        'uuid' => 'hh-uuid'
      }
    }
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
        expect(subject.results[:new_numbers]).to eq Set.new
      end
      it 'pre_existing_numbers => Set.new' do
        expect(subject.results[:pre_existing_numbers]).to eq Set.new
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
          new_numbers:          Set.new(['1234567890','4561237890']),
          pre_existing_numbers: Set.new(['1214567890','4561923780']),
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

    it 'saves households & leads at given redis keys' do
      subject.save(redis_keys, parsed_households)

      redis            = Redis.new
      stop_index       = ENV['REDIS_PHONE_KEY_INDEX_STOP'].to_i
      phone            = parsed_households.keys.first
      key              = "key:#{phone[0..stop_index]}"
      hkey             = phone[stop_index+1..-1]
      saved_households = redis.hgetall(key)
      household        = JSON.parse(saved_households[hkey])

      expect(household['leads']).to eq parsed_households[phone]['leads']
      expect(household['uuid']).to eq parsed_households[phone]['uuid']
    end
  end
end
