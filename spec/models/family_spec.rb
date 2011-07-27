require "spec_helper"

describe Family do

  describe "attributes" do

    let(:family) { Factory(:family) }
    it "can apply an original attribute" do
      value = 'some@some.com'
      family.apply_attribute('Email', value)
      family.Email.should == value
    end
  end


end
