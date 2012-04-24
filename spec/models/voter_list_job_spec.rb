require "spec_helper"

describe VoterListJob do
  let(:s3){ mock }
  let(:mailer){ mock }

  describe "import" do
    before :each do
      @account = Factory(:account)
      @campaign = Factory(:preview, :account => @account)
      @separator = ","
      @voter_list_name = "voter list name"
      @json_csv_column_headers = ["Phone", "LAST"].to_json
      @campaign_id = @campaign.id
      @csv_to_system_map = {"Phone" => "Phone", "LAST" =>"LastName"}
      VoterList.stub(:delete_from_s3)
      VoterList.stub(:read_from_s3).and_return(s3)
      UserMailer.stub(:new).and_return(mailer)
    end

    describe "requirements" do

      it "needs a list name" do
        job = VoterListJob.new(@separator, @json_csv_column_headers, @csv_to_system_map, '', '', @campaign.id, @account.id, nil, nil,"")
        mailer.should_receive(:voter_list_upload)
        job.perform['errors'].first.should include "Name can't be blank"
      end

      it "should not save a list if the user already has a list with the same name" do
        Factory(:voter_list, :account => @account, :campaign_id => @campaign.id, :name => "abcd")
        job = VoterListJob.new(@separator, @json_csv_column_headers, @csv_to_system_map, '', 'abcd', @campaign.id, @account.id, nil, nil,"")
        mailer.should_receive(:voter_list_upload)
        job.perform['errors'].should include "Name for this list is already taken."
      end
    end

    describe "after import" do
      before :each do
        @csv_filename = "valid_voters_list_#{Time.now.to_i}_#{rand(999)}"
      end

      it "saves all the voters in the csv according to the mappings" do
        Voter.delete_all
        job = VoterListJob.new(@separator, @json_csv_column_headers, @csv_to_system_map, @csv_filename, 'abcd', @campaign.id, @account.id, nil, nil,"")
        mailer.should_receive(:voter_list_upload)
        s3.should_receive(:value).and_return(File.open("#{fixture_path}/files/valid_voters_list.csv").read)

        job.perform
        Voter.count.should == 2
        Voter.first.Phone.should == "1234567895"
        Voter.first.LastName.should == "Bar"
      end

      it "removes the temporary file from disk" do
        temp_filename = "#{Rails.root}/tmp/#{@csv_filename}"
        job = VoterListJob.new(@separator, @json_csv_column_headers, @csv_to_system_map, @csv_filename, 'abcd', @campaign.id, @account.id, nil, nil,"")
        mailer.should_receive(:voter_list_upload)
        s3.should_receive(:value).and_return(File.open("#{fixture_path}/files/valid_voters_list.csv").read)
        job.perform
      end
    end

    describe "custom fields" do
      it "creates previously uncreated custom columns" do
        @csv_filename = "valid_voters_list_#{Time.now.to_i}_#{rand(999)}"
        custom_field = "Custom"
        Voter.delete_all
        job = VoterListJob.new(@separator, ["Phone", "Custom"].to_json, {"Phone"=>"Phone", custom_field=>custom_field}, @csv_filename, 'abcd', @campaign.id, @account.id, nil, nil,"")
        mailer.should_receive(:voter_list_upload)
        s3.should_receive(:value).and_return(File.open("#{fixture_path}/files/voters_custom_fields_list.csv").read)

        job.perform
        CustomVoterField.all.size.should == 1
        custom_fields = Voter.all.collect { |voter| voter.get_attribute(custom_field) }
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
        job = VoterListJob.new(@separator, @json_csv_column_headers, @csv_to_system_map, @csv_filename, 'bui', @campaign.id, @account.id, nil, nil,"")
        mailer.should_receive(:voter_list_upload)
        s3.should_receive(:value).and_return(File.open("#{fixture_path}/files/invalid_voters_list.csv").read)

        job.perform['errors'].should include "Invalid CSV file. Could not import."
      end

      it "should not save the voters list entry" do
        job = VoterListJob.new(@separator,@json_csv_column_headers,@csv_to_system_map,@csv_filename,'hui',@campaign.id,@account.id,nil,nil,"")
        mailer.should_receive(:voter_list_upload)
        s3.should_receive(:value).and_return(File.open("#{fixture_path}/files/invalid_voters_list.csv").read)
        job.perform
        VoterList.all.should be_empty
      end
    end


  end

end