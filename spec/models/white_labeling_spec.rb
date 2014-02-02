require "spec_helper"

describe WhiteLabeling do
  include WhiteLabeling

  ['com', 'us', 'org', ].each do |tld|
    it "strips the last part of .#{tld} domains" do
      I18n.stub(:t).with('white_labeling.example', anything).and_return('something')
      correct_domain("example.#{tld}").should == 'example'
    end
  end

  it "defaults to impactdialing if the actual domain doesn't match" do
    correct_domain("example.com").should == 'impactdialing'
  end

  it "defaults to impactdialing if the domain isn't set" do
    correct_domain(nil).should == 'impactdialing'
  end

  it "email defaults to support@impactdialing.com" do
    white_labeled_email('localhost').should == 'support@impactdialing.com'
  end
end
