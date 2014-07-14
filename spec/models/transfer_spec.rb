require "spec_helper"

describe Transfer, :type => :model do

  describe "phone number" do
    it "should sanitize the phone number" do
      transfer = create(:transfer, phone_number: "(203) 643-0521")
      expect(transfer.phone_number).to eq('2036430521')
    end

    it "should throw validatio error if phone number is not valid" do
      transfer = build(:transfer, phone_number: "9090909")
      expect(transfer).not_to be_valid
    end

  end
end
