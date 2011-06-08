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

  describe "upload voters list" do
    let(:csv_file_upload) { {"datafile" => fixture_file_upload("files/voters_list.csv")} }
    let(:user) { Factory(:user) }
    let(:campaign) { Factory(:campaign, :user => user) }
    let(:voter_list) { Factory(:voter_list, :campaign => campaign) }

    before :each do
      Voter.destroy_all
      @result = campaign.voter_upload(
          csv_file_upload,
          user.id,
          ",",
          voter_list.id
      )
    end

    it "should be successful" do
      @result.should == {
          :uploads      => [],
          :successCount => 1,
          :failedCount  => 0
      }
    end

    it "should parse it and save to the voters list table" do
      voter = Voter.first

      voter.campaign_id.should == campaign.id
      voter.user_id.should == user.id
      voter.voter_list_id.should == voter_list.id

      # check some values from the csv fixture
      voter.Phone.should == "1234567895"
      voter.FirstName.should == "Foo"
      voter.LastName.should == "Bar"
      voter.Email.should == "foo@bar.com"
      voter.MiddleName.should == "FuBur"
      voter.Suffix.should be_empty
    end

    it "should update only DWID as the CustomId if both DWID and VAN ID are present" do
      Voter.first.CustomID.should == "987"
    end
  end
end
