require "spec_helper"

describe VoterListsController do

  describe "api" do
    let(:account) { Factory(:account, api_key: "abc123") }
    before(:each) do
      @user = Factory(:user, account_id: account.id)
    end

    describe "index" do
      it "should list voter lists for a campaign" do
        voter_list = Factory(:voter_list)
        campaign = Factory(:campaign, :account => account, :active => true, voter_lists: [voter_list])
        get :index, campaign_id: campaign.id, :api_key=> 'abc123', :format => "json"
        response.body.should eq( "[{\"voter_list\":{\"enabled\":true,\"id\":#{voter_list.id},\"name\":\"#{voter_list.name}\"}}]")
      end
    end

    describe "show" do
      it "should shows voter list " do
        voter_list = Factory(:voter_list)
        campaign = Factory(:campaign, :account => account, :active => true, voter_lists: [voter_list, Factory(:voter_list)])
        get :show, campaign_id: campaign.id, id: voter_list.id, :api_key=> 'abc123', :format => "json"
        response.body.should eq( "{\"voter_list\":{\"enabled\":true,\"id\":#{voter_list.id},\"name\":\"#{voter_list.name}\"}}")
      end

      it "should throws 404 if campaign not found " do
        voter_list = Factory(:voter_list)
        campaign = Factory(:campaign, :account => account, :active => true, voter_lists: [voter_list, Factory(:voter_list)])
        get :show, campaign_id: 100, id: voter_list.id, :api_key=> 'abc123', :format => "json"
        response.body.should eq( "{\"message\":\"Resource not found\"}" )
      end

      it "should throws 404 if voter list not found " do
        voter_list = Factory(:voter_list)
        campaign = Factory(:campaign, :account => account, :active => true, voter_lists: [voter_list, Factory(:voter_list)])
        get :show, campaign_id: campaign.id, id: 100, :api_key=> 'abc123', :format => "json"
        response.body.should eq( "{\"message\":\"Resource not found\"}" )
      end

    end

    describe "enable" do
      it "should enable voter list " do
        voter_list = Factory(:voter_list, enabled: false)
        campaign = Factory(:campaign, :account => account, :active => true, voter_lists: [voter_list, Factory(:voter_list)])
        put :enable, campaign_id: campaign.id, id: voter_list.id, :api_key=> 'abc123', :format => "json"
        response.body.should eq( "{\"message\":\"Voter List enabled\"}")
      end

    end

    describe "disable" do
      it "should disable voter list " do
        voter_list = Factory(:voter_list, enabled: true)
        campaign = Factory(:campaign, :account => account, :active => true, voter_lists: [voter_list, Factory(:voter_list)])
        put :disable, campaign_id: campaign.id, id: voter_list.id, :api_key=> 'abc123', :format => "json"
        response.body.should eq( "{\"message\":\"Voter List disabled\"}")
      end

    end

    describe "update" do
      it "should update voter list " do
        voter_list = Factory(:voter_list, enabled: true, name: "abc")
        campaign = Factory(:campaign, :account => account, :active => true, voter_lists: [voter_list, Factory(:voter_list)])
        put :update, campaign_id: campaign.id, id: voter_list.id, voter_list: {name: "xyz"}, :api_key=> 'abc123', :format => "json"
        response.body.should eq( "{\"message\":\"Voter List updated\"}" )
        voter_list.reload.name.should  eq('xyz')
      end
    end

    describe "destroy" do
      it "should update voter list " do
        voter_list = Factory(:voter_list, enabled: true, name: "abc")
        campaign = Factory(:campaign, :account => account, :active => true, voter_lists: [voter_list, Factory(:voter_list)])
        delete :destroy, campaign_id: campaign.id, id: voter_list.id, :api_key=> 'abc123', :format => "json"
        response.body.should eq( "{\"message\":\"This opeartion is not permitted\"}")
      end
    end

    describe "create" do

      it "should create new voter list" do
        csv_file_upload =  {"datafile" => fixture_file_upload("/files/valid_voters_list.csv")}
        campaign = Factory(:campaign, :account => account, :active => true)
        Resque.should_receive(:enqueue)
        post :create, campaign_id: campaign.id, voter_list: {name: "abc.csv", separator: ",", headers: "[]", csv_to_system_map: "{\"Phone\": \"Phone\"}",
        s3path: "abc"}, upload: csv_file_upload, :api_key=> 'abc123', :format => "json"
        response.body.should match(/{\"voter_list\":{\"enabled\":true,\"id\":(.*),\"name\":\"abc.csv\"}}/)
      end

      it "should throw validation error" do
        csv_file_upload =  {"datafile" => fixture_file_upload("/files/voter_list.xsl")}
        campaign = Factory(:campaign, :account => account, :active => true)
        post :create, campaign_id: campaign.id, voter_list: {name: "abc", separator: ",", headers: "[]", csv_to_system_map: "{\"Phone\": \"Phone\"}",
        s3path: "abc"}, upload: csv_file_upload, :api_key=> 'abc123', :format => "json"
        response.body.should eq("{\"errors\":{\"base\":[\"Wrong file format. Please upload a comma-separated value (CSV) or tab-delimited text (TXT) file. If your list is in Excel format (XLS or XLSX), use \\\"Save As\\\" to change it to one of these formats.\"]}}")
      end

      it "should throw validation error if file not uploaded" do
        campaign = Factory(:campaign, :account => account, :active => true)
        post :create, campaign_id: campaign.id, voter_list: {name: "abc", separator: ",", headers: "[]", csv_to_system_map: "{\"Phone\": \"Phone\"}",
        s3path: "abc"}, upload: nil, :api_key=> 'abc123', :format => "json"
        response.body.should eq("{\"errors\":{\"uploaded_file_name\":[\"can't be blank\"],\"base\":[\"Please upload a file.\"]}}")
      end

    end


  end
  # render_views
  #
  # before :each do
  #   @current_user = Factory(:user)
  #   login_as @current_user
  # end
  #
  #
  # describe "voters list" do
  #   let(:csv_file_upload) { {"datafile" => fixture_file_upload("/files/valid_voters_list.csv")} }
  #
  #   before :each do
  #     @campaign = Factory(:predictive, :account => @current_user.account)
  #   end
  #
  #
  #
  #   describe "create voter list" do
  #     def import(parameters={})
  #       defaults = {
  #           :separator => ",",
  #           :voter_list_name => "voter list name",
  #           :json_csv_column_headers => ["Phone", "LAST"].to_json,
  #           :campaign_id => @campaign.id,
  #           :csv_to_system_map => {
  #               "Phone" => "Phone",
  #               "LAST" =>"LastName"
  #           }
  #       }
  #       post :import, defaults.merge(parameters)
  #     end
  #
  #     describe "valid csv file" do
  #       before :each do
  #         session[:voters_list_upload] = nil
  #         AWS::S3::S3Object.stub(:store)
  #         post :create,
  #              :campaign_id => @campaign.id,
  #              :upload => csv_file_upload
  #       end
  #
  #
  #       it "renders the mappings screen" do
  #         flash[:error].should be_blank
  #         response.code.should == "200"
  #         response.should render_template("column_mapping")
  #       end
  #
  #       describe "missing header info" do
  #         let(:csv_file_upload) { {"datafile" => fixture_file_upload("/files/voters_with_nil_header_info.csv")} }
  #
  #         it "ignores columns without a header" do
  #           post :create, :campaign_id => @campaign.id
  #           assigns(:csv_column_headers).size.should == 2
  #         end
  #       end
  #
  #     end
  #   end
  # end
end
