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

  it "generates its own name if one isn't provided" do
    user = Factory(:user)
    campaign = user.campaigns.create!
    campaign.name.should == 'Untitled 1'
    campaign = user.campaigns.create!
    campaign.name.should == 'Untitled 2'
  end

  it "doesn't overwrite a name that has been explicitly set" do
    user = Factory(:user)
    campaign = user.campaigns.create!(:name => 'Titled')
    campaign.name.should == 'Titled'
  end

  it "should not invoke Twilio if caller id is not present" do
    Twilio.should_not_receive(:new)
    campaign = Factory(:campaign)
    campaign.caller_id = nil
    campaign.save
  end
end
