require 'spec_helper'

describe 'CallFlow::Web::Util' do
  describe '.filter(whitelisted_keys, hash_of_data)' do
    it 'returns a copy of hash_of_data with only whitelisted_keys/values' do
      whitelist = ['FirstName', 'Email', 'Phone']
      data = {
        'first_name' => Forgery(:name).first_name,
        'last_name' => Forgery(:name).last_name,
        'email' => Forgery(:email).address,
        'phone' => Forgery(:address).phone,
        'address' => Forgery(:address).street_address
      }
      expect(CallFlow::Web::Util.filter(whitelist, data)).to eq({
        'first_name' => data['first_name'],
        'email' => data['email'],
        'phone' => data['phone']
      })
    end
  end

  describe '.build_flags(whitelisted_keys)' do
    it 'returns a hash w/ elements like "#{key}_flag" => true' do
      whitelist = ['Phone', 'Email']
      expect(CallFlow::Web::Util.build_flags(whitelist)).to eq({
        'Phone_flag' => true,
        'Email_flag' => true
      })
    end

    it 'the returned hash only contains keys that are VoterList::VOTER_DATA_COLUMNS values' do
      whitelist = ['Phone', 'Email', 'ContributionLevel']
      expect(CallFlow::Web::Util.build_flags(whitelist)).to eq({
        'Phone_flag' => true,
        'Email_flag' => true
      })
    end

    it 'always returns at least {"Phone_flag" => true}' do
      expect(CallFlow::Web::Util.build_flags([])).to eq({
        'Phone_flag' => true
      })
    end

    it 'can handle nil argument' do
      expect(CallFlow::Web::Util.build_flags).to eq({
        'Phone_flag' => true
      })
    end
  end
end