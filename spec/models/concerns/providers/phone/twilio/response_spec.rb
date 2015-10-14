require 'rails_helper'

describe Providers::Phone::Twilio::Response do
  subject{ Providers::Phone::Twilio::Response }

  let(:error_response) do
    subject.new do
      raise Twilio::REST::RequestError, "sorry mate"
    end
  end
  describe '.new(&block)' do
    it 'sets @resource to result of yield' do
      some_instance = double('SomeInstance').as_null_object
      target = subject.new{ some_instance }
      expect(target.resource).to eq some_instance
    end

    it 'sets @error to false' do
      target = subject.new
      expect(target.error?).to be_falsey
    end
  end

  describe 'testing response success' do
    describe '#success?' do
      it 'returns true when @error is false' do
        target = subject.new
        expect(target.success?).to be_truthy
      end

      it 'returns false when @error is true' do
        target = subject.new{ raise Twilio::REST::RequestError, "oops" }
        expect(target.success?).to be_falsey
      end
    end

    describe '#error?' do
      it 'returns true when @error is true' do
        target = subject.new{ raise Twilio::REST::RequestError, "sonofa" }
        expect(target.error?).to be_truthy
      end

      it 'returns false when RestException node is not found' do
        target = subject.new
        expect(target.error?).to be_falsey
      end
    end
  end
end
