require "spec_helper"

describe VoterList do

  it "can return all voter lists of the given ids" do
    v = 3.times.map { Factory(:voter_list) }
    VoterList.by_ids([v.first.id, v.last.id]).should == [v.first, v.last]
  end

  it "validates the uniqueness of name in a case insensitive manner" do
    user = Factory(:user)
    Factory(:voter_list, :name => 'same', :account => user.account)
    Factory.build(:voter_list, :name => 'Same', :account => user.account).should have(1).error_on(:name)
  end

  describe "enable and disable voter lists" do
    let(:campaign) { Factory(:campaign) }
    it "can disable all voter lists in the given scope" do
      Factory(:voter_list, :campaign => campaign, :enabled => true)
      Factory(:voter_list, :campaign => campaign, :enabled => true)
      Factory(:voter_list, :campaign => Factory(:campaign), :enabled => true)
      campaign.voter_lists.disable_all
      VoterList.all.map(&:enabled).should == [false, false, true]
    end
    it "can enable all voter lists in the given scope" do
      Factory(:voter_list, :campaign => campaign, :enabled => false)
      Factory(:voter_list, :campaign => campaign, :enabled => false)
      Factory(:voter_list, :campaign => Factory(:campaign), :enabled => false)
      campaign.voter_lists.enable_all
      VoterList.all.map(&:enabled).should == [true, true, false]
    end
  end

  describe "upload voters list" do
    let(:csv_file_upload) {
      source_file = "#{fixture_path}/files/valid_voters_list.csv"
      temp_dir = "#{fixture_path}/test_tmp"
      temp_filename = "#{temp_dir}/valid_voters_list.csv"
      FileUtils.cp source_file, temp_filename
      temp_filename
    }
    let(:user) { Factory(:user) }
    let(:campaign) { Factory(:campaign, :account => user.account) }
    let(:voter_list) { Factory(:voter_list, :campaign => campaign, :account => user.account) }

    describe "import from csv" do
      USER_MAPPINGS = CsvMapping.new({
                                         "LAST" => "LastName",
                                         "FIRSTName" => "FirstName",
                                         "Phone" => "Phone",
                                         "Email" => "Email",
                                         "ID" => "ID",
                                         "Age" => "Age",
                                         "Gender" => "Gender",
                                     })
      before :each do
        Voter.destroy_all
        @result = voter_list.import_leads(
            USER_MAPPINGS,
            csv_file_upload,
            ",")
      end

      it "should be successful" do
        @result.should == {
            :successCount => 2,
            :failedCount => 0
        }
      end

      it "should treat a duplicate phone number as a new voter" do
        Voter.count.should == 2
      end

      it "should parse it and save to the voters list table" do
        Voter.count.should == 2

        voter = Voter.find_by_Email("foo@bar.com")
        voter.campaign_id.should == campaign.id
        voter.account_id.should == user.account.id
        voter.voter_list_id.should == voter_list.id

          # check some values from the csv fixture
        voter.Phone.should == "1234567895"
        voter.FirstName.should == "Foo"
        voter.CustomID.should == "987"
        voter.LastName.should == "Bar"
        voter.Email.should == "foo@bar.com"
        voter.MiddleName.should be_blank
        voter.Suffix.should be_blank
      end

      it "should add a family member when two voters in the same voters list have same phone number" do
        pending "family functionality has been turned off" do
          Family.count.should == 1
          Voter.first.num_family.should == 2

          family_member = Family.first
          family_member.campaign_id.should == campaign.id
          family_member.account_id.should == user.account.id
          family_member.voter_list_id.should == voter_list.id

          # check some values from the csv fixture
          family_member.Phone.should == "1234567895"
          family_member.FirstName.should == "Chocolate"
          family_member.LastName.should == "Bar"
          family_member.Email.should == "choco@bar.com"
          family_member.MiddleName.should be_blank
          family_member.Suffix.should be_blank
        end
      end

      it "should ignore the same phone is repeated in another voters list for the same campaign" do
        another_voter_list = Factory(:voter_list, :campaign => campaign, :account => user.account)
        another_voter_list.import_leads(
            USER_MAPPINGS,
            csv_file_upload,
            ",").should ==
            {
                :successCount => 2,
                :failedCount => 0
            }
      end
      it "should add even if the same phone is repeated in a different campaign" do
        another_voter_list = Factory(:voter_list,
                                     :campaign => Factory(:campaign, :account => user.account),
                                     :account => user.account)
        another_voter_list.import_leads(
            USER_MAPPINGS,
            csv_file_upload,
            ",").should ==
            {
                :successCount => 2,
                :failedCount => 0
            }
      end
    end

    describe "with custom fields" do
      let(:csv_file) {
        source_file = "#{fixture_path}/files/voters_custom_fields_list.csv"
        temp_dir = "#{fixture_path}/test_tmp"
        temp_filename = "#{temp_dir}/valid_voters_list.csv"
        FileUtils.cp source_file, temp_filename
        temp_filename
      }

      let(:mappings) { CsvMapping.new({ "Phone" => "Phone", "Custom" =>"Custom"}) }

      it "creates custom fields when they do not exist" do
        custom_field = "Custom"
        voter_list = Factory(:voter_list, :campaign => Factory(:campaign, :account => user.account), :account => user.account)
        voter_list.import_leads(mappings, csv_file, ",").should == {:successCount => 2, :failedCount => 0}
        CustomVoterField.find_by_name(custom_field).should_not be_nil
        CustomVoterField.all.size.should == 1

        voter_list.voters[0].get_attribute(custom_field).should ==  "Foo" #this is set in the csv file, may be the test should have this
        voter_list.voters[1].get_attribute(custom_field).should ==  "Bar" #this is set in the csv file, may be the test should have this
      end
    end

  end


  describe "dial" do
    let(:voter_list) { Factory(:voter_list, :campaign => Factory(:campaign, :calls_in_progress => true)) }
    it "dials all the voters who have not been dialed yet" do
      voter1 = Factory(:voter, :voter_list => voter_list, :campaign => voter_list.campaign)
      voter2 = Factory(:voter, :voter_list => voter_list, :campaign => voter_list.campaign)
      voter1.should_receive(:dial)
      voter2.should_receive(:dial)
      voters = mock
      voters.should_receive(:to_be_dialed).and_return(mock('voters', :randomly => [voter1, voter2]))
      voter_list.stub!(:voters).and_return(voters)
      voter_list.dial
    end

    it "gives the count of remaining voters" do
      voter_list = Factory(:voter_list)
      Factory(:voter, :voter_list => voter_list, :status => CallAttempt::Status::SUCCESS)
      Factory(:voter, :voter_list => voter_list)
      voter_list.voters_remaining.should == 1
    end
  end
end
