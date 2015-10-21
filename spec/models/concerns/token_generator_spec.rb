require 'rails_helper'

describe 'TokenGenerator' do
  subject{ TokenGenerator }

  describe '.sha_hexdigest(*args)' do
    let(:args){ [Time.now, (1..10).map{ rand.to_s }] }

    it 'generates a string 40 characters long based on args' do
      expect(TokenGenerator.sha_hexdigest(*args).length).to eq 40
    end

    it 'is a SHA1 hex digest of the args joined on "--"' do
      expect(TokenGenerator.sha_hexdigest(*args)).to eq Digest::SHA1.hexdigest(args.flatten.join('--'))
    end
  end
end
