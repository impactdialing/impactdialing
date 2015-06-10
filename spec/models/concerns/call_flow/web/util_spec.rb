require 'rails_helper'

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
end