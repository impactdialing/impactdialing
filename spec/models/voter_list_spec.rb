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
  
  it "returns all the active voter list ids of a campaign" do
    campaign = Factory(:campaign)
    v1 = Factory(:voter_list, :id => 123, :campaign => campaign, :active => true, :enabled => true)
    v2 = Factory(:voter_list, :id => 1234, :campaign => campaign, :active => true, :enabled => true)
    v4 = Factory(:voter_list, :id => 123456, :campaign => campaign, :active => false, :enabled => true)
    v5 = Factory(:voter_list, :id => 1234567, :active => true, :enabled => true)
    VoterList.active_voter_list_ids(campaign.id).should == [123,1234]
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
    let(:campaign) { Factory(:preview, :account => user.account) }
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
      end

      it "should be successful" do        
        s3 = mock
        VoterList.should_receive(:read_from_s3).and_return(s3)
        s3.should_receive(:value).and_return(File.open("#{csv_file_upload}").read)        
        @result = voter_list.import_leads(
            USER_MAPPINGS,
            csv_file_upload,
            ",")        
        @result.should == {
            :successCount => 2,
            :failedCount => 0
        }
      end
      
      it "should upload all columns expect the Not Available one" do        
        MAPPINGS = CsvMapping.new({"Phone"=>"Phone", "Name"=>"", "Email"=>"Email"})
        s3 = mock
        VoterList.should_receive(:read_from_s3).and_return(s3)        
        s3.should_receive(:value).and_return(File.open("#{fixture_path}/files/missing_field_list.csv").read)
        @result = voter_list.import_leads(MAPPINGS,"#{fixture_path}/files/missing_field_list.csv",",")
        @result.should == {
            :successCount => 2,
            :failedCount => 0
        }
        Voter.all.count.should eq(2)
      end

      it "should treat a duplicate phone number as a new voter" do
        s3 = mock
        VoterList.should_receive(:read_from_s3).and_return(s3)
        s3.should_receive(:value).and_return(File.open("#{csv_file_upload}").read)        
        @result = voter_list.import_leads(
            USER_MAPPINGS,
            csv_file_upload,
            ",")        
        
        Voter.count.should == 2
      end

      it "should parse it and save to the voters list table" do
        s3 = mock
        VoterList.should_receive(:read_from_s3).and_return(s3)
        s3.should_receive(:value).and_return(File.open("#{csv_file_upload}").read)        
        @result = voter_list.import_leads(
            USER_MAPPINGS,
            csv_file_upload,
            ",")                
    
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

      it "should ignore the same phone is repeated in another voters list for the same campaign" do
        s3 = mock
        VoterList.should_receive(:read_from_s3).twice.and_return(s3)
        s3.should_receive(:value).twice.and_return(File.open("#{csv_file_upload}").read)        
        @result = voter_list.import_leads(
            USER_MAPPINGS,
            csv_file_upload,
            ",")        
        
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
        s3 = mock
        VoterList.should_receive(:read_from_s3).and_return(s3)
        s3.should_receive(:value).and_return(File.open("#{csv_file_upload}").read)        
        
        another_voter_list = Factory(:voter_list,
                                     :campaign => Factory(:progressive, :account => user.account),
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
      
      describe "If another voter uploaded with same CustoomID, it update older voter" do
        let(:csv_file_upload_with_duplicate_custom_id) {
          source_file = "#{fixture_path}/files/voter_list_with_duplicate_custom_id_field.csv"
          temp_dir = "#{fixture_path}/test_tmp"
          temp_filename = "#{temp_dir}/voter_list_with_duplicate_custom_id_field.csv"
          FileUtils.cp source_file, temp_filename
          temp_filename
        }

        before(:each) do
          @another_voter_list = Factory(:voter_list, :campaign => campaign, :account => user.account)
          s3 = mock
          VoterList.should_receive(:read_from_s3).twice.and_return(s3)
          s3.should_receive(:value).and_return(File.open("#{csv_file_upload}").read)        
          s3.should_receive(:value).and_return(File.open("#{csv_file_upload_with_duplicate_custom_id}").read)        
          
          @result = voter_list.import_leads(
              USER_MAPPINGS,
              csv_file_upload,
              ",")                
          
          @another_voter_list.import_leads(
              USER_MAPPINGS,
              csv_file_upload_with_duplicate_custom_id,
              ",").should ==
              {
                  :successCount => 2,
                  :failedCount => 0
              }
        end

        it "update the voter with same id, instead of add new voter" do
          Voter.count.should == 3
        end
        
        it "add the updated voter to new voter list and remove from older list" do
          voter_list.voters.count.should == 1
          @another_voter_list.voters.count.should == 2
        end
        
        it "update the new voter fields, if there any" do
          voter = Voter.find_by_CustomID("123")
          voter.FirstName.should == "Foo_updated"
          voter.Email.should == "foo2@bar.com"
        end
        
        it "also upadate the custom voter fields" do
          voter = Voter.find_by_CustomID("123")
          custom_voter_field_value = CustomVoterFieldValue.find_by_voter_id_and_custom_voter_field_id(voter.id, CustomVoterField.find_by_name("Gender").id)
          custom_voter_field_value.value.should == "Male_updated"
        end
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
        s3 = mock
        VoterList.should_receive(:read_from_s3).and_return(s3)
        s3.should_receive(:value).and_return(File.open("#{csv_file}").read)        
        
        custom_field = "Custom"
        voter_list = Factory(:voter_list, :campaign => Factory(:predictive, :account => user.account), :account => user.account)
        voter_list.import_leads(mappings, csv_file, ",").should == {:successCount => 2, :failedCount => 0}
        CustomVoterField.find_by_name(custom_field).should_not be_nil
        CustomVoterField.all.size.should == 1
        custom_fields = voter_list.voters.collect{|voter| voter.get_attribute(custom_field)}
        custom_fields.length.should eq(2)
        custom_fields.should include("Foo")
        custom_fields.should include("Bar")
      end

      it "should not process custom fields for a voters with an invalid phone" do
        s3 = mock
        VoterList.should_receive(:read_from_s3).and_return(s3)
        s3.should_receive(:value).and_return(File.open("#{fixture_path}/files/missing_phone_with_custom_fields_list.csv").read)        
        
        mappings = CsvMapping.new({"Phone"=>"Phone", "Name"=>"", "Custom"=>"Custom"})
        @result = voter_list.import_leads(mappings,"#{fixture_path}/files/missing_phone_with_custom_fields_list.csv",",")
        @result.should == { :successCount => 2,  :failedCount => 1 }
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
      Voter.stub_chain(:to_be_dialed, :find_in_batches).and_yield [ voter1, voter2 ]
      voter_list.dial
    end

    it "gives the count of remaining voters" do
      voter_list = Factory(:voter_list)
      Factory(:voter, :voter_list => voter_list, :status => CallAttempt::Status::SUCCESS)
      Factory(:voter, :voter_list => voter_list)
      voter_list.voters_remaining.should == 1
    end
  end
  
  describe "valid file" do
     it "should consider csv file extension as valid" do
       VoterList.valid_file?("abc.csv").should be_true
     end
     
     it "should consider CSV file extension as valid" do
       VoterList.valid_file?("abc.CSV").should be_true
     end
     
     it "should consider txt file extension as valid" do
       VoterList.valid_file?("abc.txt").should be_true
     end
     
     it "should consider txt file extension as valid" do
       VoterList.valid_file?("abc.txt").should be_true
     end
     
     it "should consider null fileas invalid" do
       VoterList.valid_file?(nil).should be_false
     end
     
     it "should consider non csv txt file as invalid" do
       VoterList.valid_file?("abc.psd").should be_false
     end
  end
  
  describe "seperator from file extension" do
    it "should return , for csv file" do
      VoterList.separator_from_file_extension("abc.csv").should eq(',')
    end
    
    it "should return \t for txt file" do
      VoterList.separator_from_file_extension("abc.txt").should eq("\t")
    end
    
  end
  
  describe "create csv to system map" do
     it "should use voter primary attribute for mapping" do
       account = Factory(:account)
       VoterList.create_csv_to_system_map(['Phone'], account).should eq ({"Phone"=>"Phone"})
     end
     
     it "should use account custom attribute for mapping" do
       account = Factory(:account)
       Factory(:custom_voter_field, name: "test", account_id: account.id)
       VoterList.create_csv_to_system_map(['test'], account).should eq ({"test"=>"test"})
     end
     
     it "should use assign  new custom attribute for mapping" do
       account = Factory(:account)
       VoterList.create_csv_to_system_map(['new test'], account).should eq ({"new test"=>"new test"})
     end
     
     it "should use use primary attribute and custom field and assign new attribute" do
       account = Factory(:account)
       Factory(:custom_voter_field, name: "Region", account_id: account.id)
       Factory(:custom_voter_field, name: "Club", account_id: account.id)
       VoterList.create_csv_to_system_map(['Phone','FirstName','Region','Club','Mobile'], account).should eq ({"Phone"=>"Phone", "FirstName"=>"FirstName", "Region"=>"Region", "Club"=>"Club", "Mobile"=>"Mobile"})
     end     
  end
  
  describe "voter enable callback after save" do
    
    it "should enable all voters when list enabled" do
      voter_list = Factory(:voter_list, enabled: false)
      voter = Factory(:voter, voter_list: voter_list, enabled: false)
      voter_list.enabled = true
      voter_list.save
      voter.reload.enabled.should be_true
    end
    
    it "should disable all voters when list disabled" do
      voter_list = Factory(:voter_list, enabled: true)
      voter = Factory(:voter, voter_list: voter_list, enabled: true)
      voter_list.enabled = false
      voter_list.save
      voter.reload.enabled.should be_false
    end
    
  end
end
