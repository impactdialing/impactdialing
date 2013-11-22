require "spec_helper"

describe Transfer do

  describe "phone number" do
    it "should sanitize the phone number" do
      transfer = create(:transfer, phone_number: "(203) 643-0521")
      transfer.phone_number.should eq('2036430521')
    end

    it "should throw validatio error if phone number is not valid" do
      transfer = build(:transfer, phone_number: "9090909")
      transfer.should_not be_valid
    end

  end
end
