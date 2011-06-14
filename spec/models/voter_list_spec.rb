require "spec_helper"

describe VoterList do
  include ActionController::TestProcess

  describe "state" do
    it "should validate the state" do
      Factory.build(:voter_list, :state => "xyz").should_not be_valid
      Factory.build(:voter_list, :state => VoterList::States::INITIAL).should be_valid
    end
    describe "default scope" do
      it "should not give voter lists in initial state" do
        lambda { Factory(:voter_list, :state => VoterList::States::INITIAL) }.should_not change {
          VoterList.count
        }
      end
      it "should give valid voter lists" do
        lambda { Factory(:voter_list, :state => VoterList::States::VALID) }.should change {
          VoterList.count
        }.by(1)
      end
    end
    it "should give all records when unscoped" do
      lambda { Factory(:voter_list, :state => VoterList::States::INITIAL) }.should change {
        VoterList.unscoped { VoterList.count }
      }
    end
  end

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
    let(:voter_list) { Factory(:voter_list, :campaign => campaign, :user_id => user.id, :state => VoterList::States::INITIAL) }

    before :each do
      Voter.destroy_all
      @result = voter_list.import_leads(
          {
              "LAST"      => "LastName",
              "FIRSTName" => "FirstName",
              "Phone"     => "Phone",
              "Email"     => "Email",
              "VAN ID"    => "VAN ID",
              "Age"       => "Age",
              "Gender"    => "Gender",
              "DWID"      => "DWID"
          },
          csv_file_upload,
          ",")
    end

    it "should be successful" do
      @result.should == {
          :messages     => [],
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

    it "should add a family member when two voters have same phone number" do
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

    it "should update only DWID as the CustomId if both DWID and VAN ID are present" do
      Voter.first.CustomID.should == "987"
    end
  end
end