require "spec_helper"

describe WhiteLabeling, :type => :model do
  include WhiteLabeling

  ['com', 'us', 'org', ].each do |tld|
    it "strips the last part of .#{tld} domains" do
      allow(I18n).to receive(:t).with('white_labeling.example', anything).and_return('something')
      expect(correct_domain("example.#{tld}")).to eq('example')
    end
  end

  it "defaults to impactdialing if the actual domain doesn't match" do
    expect(correct_domain("example.com")).to eq('impactdialing')
  end

  it "defaults to impactdialing if the domain isn't set" do
    expect(correct_domain(nil)).to eq('impactdialing')
  end

  it "email defaults to support@impactdialing.com" do
    expect(white_labeled_email('localhost')).to eq('support@impactdialing.com')
  end
end
