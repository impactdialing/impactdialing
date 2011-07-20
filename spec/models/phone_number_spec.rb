require "spec_helper"

describe PhoneNumber do
  it "validates a number with ten digits" do
    PhoneNumber.new("0123456789").should be_valid
  end
  it "validates a number with more than ten digits" do
    PhoneNumber.new("01234567899").should be_valid
  end

  it "does not validate a number which has non-digits" do
    PhoneNumber.new("0123456abc").should_not be_valid
  end

  it "does not validate a number with less than ten digits" do
    PhoneNumber.new("0123").should_not be_valid
  end

  it "sanitizes the number" do
    PhoneNumber.new("(415) 347-5723").to_s.should == "4153475723"
  end
end
