require 'rails_helper'

describe CallFlow::Web::Event do
  let(:redis){ Redis.new }
  let(:account_id){ 3 }

  subject{ CallFlow::Web::Event.new(account_id) }

  describe "#channel" do
    context "the account channel exists" do
      before do
        allow(TokenGenerator).to receive(:uuid){ 'asdf' }
      end
      it "returns a string" do
        expect(subject.channel).to eq("asdf")
      end
    end
    context "the account channel does not exist" do
      it "generates the account channel" do
        expect(subject.channel).to be_present
      end
      it "stores generated account channel" do
        generated_channel = subject.channel
        expect(subject.channel).to eq(generated_channel)
      end
      it "returns a string"
    end
  end

  describe ".new" do
    it "has an account id" do
      expect(subject.account_id).to eq(account_id)
    end
    context "when account id not present" do
      it "raises an argument error" do
        expect{subject.class.new("")}.to raise_error(ArgumentError)
      end
    end
  end

  describe '.publish' do
    subject{ CallFlow::Web::Event }
    it "submits a request to Pusher API" do
      response = nil
      VCR.use_cassette('Pusher success request', {
        :match_requests_on => [
          :method,
          :host,
          VCR.request_matchers.uri_without_param(:auth_timestamp, :auth_signature)
        ]
      }) do
        response = subject.publish("channel_name", "event_name", { payload: "data" })
      end
      expect(response).to be_kind_of Hash
    end
  end
end
