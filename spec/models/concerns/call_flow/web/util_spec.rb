require 'rails_helper'
include ERB::Util

describe 'CallFlow::Web::Util' do
  describe '.autolink(string)' do
    subject{ CallFlow::Web::Util }

    it 'converts plain text email addresses (e.g. joe@test.com) to links' do
      email = 'joe@test.com'
      expect(subject.autolink(email)).to eq "<a target=\"_blank\" href=\"mailto:#{email}\">#{email}</a>"
    end

    it 'converts plain text URLs (e.g. www.test.com or test.com) to links' do
      url = 'test.com'
      expect(subject.autolink(url)).to eq "<a target=\"_blank\" href=\"http://#{url}\">#{url}</a>"
    end

    it 'makes best effort to ignore typos that look like domains' do
      email = 'No-email.Please use phone'
      expect(subject.autolink(email)).to eq email
    end

    it 'makes best effort to ignore typos that look like emails' do
      email = 'Holla-@twit'
      expect(subject.autolink(email)).to eq email
    end

    it 'ignores leading and trailing whitespace' do
      email = ' john@test.com'
      expect(subject.autolink(email)).to eq "<a target=\"_blank\" href=\"mailto:#{email}\">#{email}</a>"
    end

    it 'html encodes all values' do
      first_name = '<script>alert("blah");</script>'
      actual = subject.autolink(first_name)
      expect(actual).to eq html_escape(first_name)
    end
  end

  describe '.filter(whitelisted_keys, hash_of_data)' do
    it 'returns a copy of hash_of_data with only whitelisted_keys/values' do
      whitelist = ['FirstName', 'Phone']
      data = {
        'first_name' => Forgery(:name).first_name,
        'last_name' => Forgery(:name).last_name,
        'email' => Forgery(:email).address,
        'phone' => Forgery(:address).phone,
        'address' => Forgery(:address).street_address
      }
      expect(CallFlow::Web::Util.filter(whitelist, data)).to eq({
        'first_name' => data['first_name'],
        'phone' => data['phone']
      })
    end
  end
end
