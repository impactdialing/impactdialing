require "spec_helper"

describe ApplicationHelper do
  ['com', 'us', 'org', ].each do |tld|
    it "strips the last part of .#{tld} domains" do
      helper.stub!(:request).and_return(mock(:request, :domain => "example.#{tld}"))
      I18n.stub(:t).with('white_labeling.example', anything).and_return('something')
      helper.domain.should == 'example'
    end
  end
end
