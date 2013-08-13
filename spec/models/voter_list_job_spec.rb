require "spec_helper"

describe VoterListJob do
  let(:mailer){ double }

  describe "import" do
    before :each do
      @account = create(:account)
      @campaign = create(:preview, :account => @account)
      @separator = ","
      @voter_list_name = "voter list name"
      @json_csv_column_headers = ["Phone", "LAST"].to_json
      @campaign_id = @campaign.id
      @csv_to_system_map = {"Phone" => "phone", "LAST" =>"last_name"}
      VoterList.stub(:delete_from_s3)
      UserMailer.stub(:new).and_return(mailer)
    end


    describe "after import" do
      before :each do
        @csv_filename = "valid_voters_list_#{Time.now.to_i}_#{rand(999)}"
      end

      it "saves all the voters in the csv according to the mappings" do
        Voter.delete_all
        voter_list = create(:voter_list, separator: ",", headers: "[]", csv_to_system_map: {"Phone" => "phone", "LAST" =>"last_name"}.to_json, s3path: @csv_filename, campaign_id: @campaign.id, account_id: @account.id)
        job = VoterListJob.new(voter_list.id, nil, nil,"")
        mailer.should_receive(:voter_list_upload)
        VoterList.should_receive(:read_from_s3).and_return(File.open("#{fixture_path}/files/valid_voters_list.csv").read)

        job.perform
        Voter.count.should == 2
        Voter.first.phone.should == "1234567895"
        Voter.first.last_name.should == "Bar"
      end

    end

    describe "custom fields" do
      it "creates previously uncreated custom columns" do
        @csv_filename = "valid_voters_list_#{Time.now.to_i}_#{rand(999)}"
        custom_field = "Custom"
        Voter.delete_all
        voter_list = create(:voter_list, separator: ",", headers: "[]", csv_to_system_map: {"Phone" => "phone", custom_field=>custom_field}.to_json, s3path: @csv_filename, campaign_id: @campaign.id, account_id: @account.id)
        job = VoterListJob.new(voter_list.id, nil, nil,"")
        mailer.should_receive(:voter_list_upload)
        VoterList.should_receive(:read_from_s3).and_return(File.open("#{fixture_path}/files/voters_custom_fields_list.csv").read)

        job.perform
        CustomVoterField.all.size.should == 1
        custom_fields = Voter.all.collect do |voter|
          VoterMethods.get_attribute(voter, custom_field)
        end
        custom_fields.length.should eq(2)
        custom_fields.should include("Foo")
        custom_fields.should include("Bar")
      end
    end

    describe "malformed csv file" do
      before :each do
        @csv_filename = "invalid_voters_list_#{Time.now.to_i}_#{rand(999)}"
        File.open(Rails.root.join('tmp', @csv_filename).to_s, "w") do |f|
          f.write(File.open("#{fixture_path}/files/invalid_voters_list.csv").read)
          f.flush
        end

      end

      it "should flash an error" do
        voter_list = create(:voter_list, separator: ",", headers: "[]", csv_to_system_map: {"Phone" => "phone"}.to_json, s3path: @csv_filename, campaign_id: @campaign.id, account_id: @account.id)
        job = VoterListJob.new(voter_list.id, nil, nil,"")

        mailer.should_receive(:voter_list_upload)
        VoterList.should_receive(:read_from_s3).and_return(File.open("#{fixture_path}/files/invalid_voters_list.csv").read)

        job.perform['errors'].should include "Invalid CSV file. Could not import."
      end

      it "should not save the voters list entry" do
        voter_list = create(:voter_list, separator: ",", headers: "[]", csv_to_system_map: {"Phone" => "phone"}.to_json, s3path: @csv_filename, campaign_id: @campaign.id, account_id: @account.id)
        job = VoterListJob.new(voter_list.id, nil, nil,"")

        mailer.should_receive(:voter_list_upload)
        VoterList.should_receive(:read_from_s3).and_return(File.open("#{fixture_path}/files/invalid_voters_list.csv").read)
        job.perform
        VoterList.all.should_not include(voter_list)
      end
    end


  end

end
