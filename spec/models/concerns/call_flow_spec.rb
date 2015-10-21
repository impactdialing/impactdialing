require 'rails_helper'

describe 'CallFlow' do
  subject{ CallFlow }

  describe '.generate_token' do
    it 'generates a time-based token, appending 10 random number strings' do
      Timecop.freeze do
        args = [Time.now, (1..10).map{ String }]
        expect(TokenGenerator).to receive(:sha_hexdigest).with(*args)
        subject.generate_token
      end
    end
  end
end
