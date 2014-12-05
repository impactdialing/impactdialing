require "rails_helper"

describe PhoneNumber do
  it "validates a number with ten digits" do
    expect(PhoneNumber.new("0123456789")).to be_valid
  end
  it "validates a number with more than ten digits" do
    expect(PhoneNumber.new("01234567899")).to be_valid
  end
  it "does not validate a number with more than 16 digits" do
    expect(PhoneNumber.new("12345678901234567")).not_to be_valid
  end
  it "does not validate a number which has non-digits" do
    expect(PhoneNumber.new("0123456abc")).not_to be_valid
  end

  it "does not validate a number with less than ten digits" do
    expect(PhoneNumber.new("0123")).not_to be_valid
  end

  it "sanitizes the number" do
    expect(PhoneNumber.new("(415) 347-5723").to_s).to eq("4153475723")
  end
end
