require "spec_helper"

describe VoterList do
  include ActionController::TestProcess
  MAPPINGS = {
      "LAST"      => "LastName",
      "FIRSTName" => "FirstName",
      "Phone"     => "Phone",
      "Email"     => "Email",
      "VAN ID"    => "VAN ID",
      "Age"       => "Age",
      "Gender"    => "Gender",
      "DWID"      => "DWID"
  }

  describe "upload voters list" do
    let(:csv_file_upload) {
      fixture_path = ActionController::TestCase.fixture_path
      source_file = "#{fixture_path}files/voters_list.csv"
      temp_dir = "#{fixture_path}test_tmp"
      temp_filename = "#{temp_dir}/voters_list.csv"
      FileUtils.cp source_file, temp_filename
      temp_filename
    }
    let(:user) { Factory(:user) }
    let(:campaign) { Factory(:campaign, :user => user) }
    let(:voter_list) { Factory(:voter_list, :campaign => campaign, :user_id => user.id) }

    before :each do
      Voter.destroy_all
      @result = voter_list.import_leads(
          MAPPINGS,
          csv_file_upload,
          ",")
    end

    it "should be successful" do
      @result.should == {
          :successCount => 2,
          :failedCount  => 0
      }
    end

    it "should parse it and save to the voters list table" do
      Voter.count.should == 1

      voter = Voter.first
      voter.campaign_id.should == campaign.id
      voter.user_id.should == user.id
      voter.voter_list_id.should == voter_list.id

      # check some values from the csv fixture
      voter.Phone.should == "1234567895"
      voter.FirstName.should == "Foo"
      voter.LastName.should == "Bar"
      voter.Email.should == "foo@bar.com"
      voter.MiddleName.should be_blank
      voter.Suffix.should be_blank
    end

    it "should add a family member when two voters in the same voters list have same phone number" do
      Family.count.should == 1
      Voter.first.num_family.should == 2

      family_member = Family.first
      family_member.campaign_id.should == campaign.id
      family_member.user_id.should == user.id
      family_member.voter_list_id.should == voter_list.id

      # check some values from the csv fixture
      family_member.Phone.should == "1234567895"
      family_member.FirstName.should == "Chocolate"
      family_member.LastName.should == "Bar"
      family_member.Email.should == "choco@bar.com"
      family_member.MiddleName.should be_blank
      family_member.Suffix.should be_blank
    end
    it "should ignore the same phone is repeated in another voters list for the same campaign" do
      another_voter_list = Factory(:voter_list, :campaign => campaign, :user_id => user.id)
      another_voter_list.import_leads(
          MAPPINGS,
          csv_file_upload,
          ",").should ==
          {
              :successCount => 0,
              :failedCount  => 2
          }
    end
    it "should add even if the same phone is repeated in a different campaign" do
      another_voter_list = Factory(:voter_list,
                                   :campaign => Factory(:campaign, :user => user),
                                   :user_id => user.id)
      another_voter_list.import_leads(
          MAPPINGS,
          csv_file_upload,
          ",").should ==
          {
              :successCount => 2,
              :failedCount  => 0
          }
    end

    it "should update only DWID as the CustomId if both DWID and VAN ID are present" do
      Voter.first.CustomID.should == "987"
    end
  end
end