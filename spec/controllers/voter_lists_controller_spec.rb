require "spec_helper"

describe VoterListsController do
  render_views

  before :each do
    @current_user = Factory(:user)
    login_as @current_user
  end
  

  describe "voters list" do
    let(:csv_file_upload) { {"datafile" => fixture_file_upload("/files/valid_voters_list.csv")} }

    before :each do
      @campaign = Factory(:predictive, :account => @current_user.account)
    end

    it "needs an uploaded file" do
      post :create, :campaign_id => @campaign.id
      flash[:error].should == ["Please click \"Choose file\" and select your list before clicking Upload."]
    end
    
    it "gives error, if either csv or txt " do
      post :create,
           :campaign_id => @campaign.id,
           :upload => {"datafile" => fixture_file_upload("/files/voter_list.xsl")}
      flash[:error].should == ["Wrong file format. Please upload a comma-separated value (CSV) or tab-delimited text (TXT) file. If your list is in Excel format (XLS or XLSX), use \"Save As\" to change it to one of these formats."]
    end
    
    describe "create voter list" do
      def import(parameters={})
        defaults = {
            :separator => ",",
            :voter_list_name => "voter list name",
            :json_csv_column_headers => ["Phone", "LAST"].to_json,
            :campaign_id => @campaign.id,
            :csv_to_system_map => {
                "Phone" => "Phone",
                "LAST" =>"LastName"
            }
        }
        post :import, defaults.merge(parameters)
      end

      describe "valid csv file" do
        before :each do
          session[:voters_list_upload] = nil
          AWS::S3::S3Object.stub(:store)
          post :create,
               :campaign_id => @campaign.id,
               :upload => csv_file_upload
        end

        it "sets the session to the new voter list entry" do
          session[:voters_list_upload].should_not be_empty
        end


        it "renders the mappings screen" do
          flash[:error].should be_blank
          response.code.should == "200"
          response.should render_template("column_mapping")
        end

        describe "missing header info" do
          let(:csv_file_upload) { {"datafile" => fixture_file_upload("/files/voters_with_nil_header_info.csv")} }

          it "ignores columns without a header" do
            post :create, :campaign_id => @campaign.id
            assigns(:csv_column_headers).size.should == 2
          end
        end
       
      end
    end
  end
end
