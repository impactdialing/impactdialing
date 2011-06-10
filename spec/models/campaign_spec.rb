require "spec_helper"

describe Campaign do
  include ActionController::TestProcess

  it "restoring makes it active" do
    campaign = Factory(:campaign, :active => false)
    campaign.restore
    campaign.active?.should == true
  end

  it "sorts by the updated date" do
    Campaign.record_timestamps = false
    older_campaign             = Factory(:campaign).tap { |c| c.update_attribute(:updated_at, 2.days.ago) }
    newer_campaign             = Factory(:campaign).tap { |c| c.update_attribute(:updated_at, 1.day.ago) }
    Campaign.record_timestamps = true
    Campaign.by_updated.all.should == [newer_campaign, older_campaign]
  end

  it "lists deleted campaigns" do
    deleted_campaign = Factory(:campaign, :active => false)
    other_campaign = Factory(:campaign, :active => true)
    Campaign.deleted.should == [deleted_campaign]
  end
end
