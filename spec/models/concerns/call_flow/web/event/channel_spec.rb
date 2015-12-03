require 'rails_helper'

describe "CallFlow::Web::Event::Channel" do
  let(:account_id){ 3 }

  subject{ CallFlow::Web::Event::Channel.new(account_id) }

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

  describe "#name" do
    context "the account channel exists" do
      before do
        allow(TokenGenerator).to receive(:uuid){ 'asdf' }
      end
      it "returns a string" do
        expect(subject.name).to eq("asdf")
      end
    end
    context "the account channel does not exist" do
      it "generates the account channel" do
        expect(subject.name).to be_present
      end
      it "stores generated account channel" do
        generated_channel = subject.name
        expect(subject.name).to eq(generated_channel)
      end
      it "returns a string"
    end
  end
end
