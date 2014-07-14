require "spec_helper"

describe VoterListsController, :type => :controller do

  before do
    WebMock.allow_net_connect!
  end

  describe "API Usage (JSON)" do
    let(:account) { create(:account) }
    before(:each) do
      @user = create(:user, account_id: account.id)
    end

    describe "index" do
      it "should list voter lists for a campaign" do
        voter_list = create(:voter_list)
        campaign = create(:campaign, :account => account, :active => true, voter_lists: [voter_list])
        get :index, campaign_id: campaign.id, :api_key=> account.api_key, :format => "json"
        expect(response.body).to eq( "[{\"voter_list\":{\"enabled\":true,\"id\":#{voter_list.id},\"name\":\"#{voter_list.name}\"}}]")
      end
    end

    describe "show" do
      it "should shows voter list " do
        voter_list = create(:voter_list)
        campaign = create(:campaign, :account => account, :active => true, voter_lists: [voter_list, create(:voter_list)])
        get :show, campaign_id: campaign.id, id: voter_list.id, :api_key=> account.api_key, :format => "json"
        expect(response.body).to eq( "{\"voter_list\":{\"enabled\":true,\"id\":#{voter_list.id},\"name\":\"#{voter_list.name}\"}}")
      end

      it "should throws 404 if campaign not found " do
        voter_list = create(:voter_list)
        campaign = create(:campaign, :account => account, :active => true, voter_lists: [voter_list, create(:voter_list)])
        get :show, campaign_id: 100, id: voter_list.id, :api_key=> account.api_key, :format => "json"
        expect(response.body).to eq( "{\"message\":\"Resource not found\"}" )
      end

      it "should throws 404 if voter list not found " do
        voter_list = create(:voter_list)
        campaign = create(:campaign, :account => account, :active => true, voter_lists: [voter_list, create(:voter_list)])
        get :show, campaign_id: campaign.id, id: 100, :api_key=> account.api_key, :format => "json"
        expect(response.body).to eq( "{\"message\":\"Resource not found\"}" )
      end

    end

    describe "enable" do
      it "should enable voter list " do
        voter_list = create(:voter_list, enabled: false)
        campaign = create(:campaign, :account => account, :active => true, voter_lists: [voter_list, create(:voter_list)])
        put :enable, campaign_id: campaign.id, id: voter_list.id, :api_key=> account.api_key, :format => "json"
        expect(response.body).to eq( "{\"message\":\"Voter List enabled\"}")
      end

    end

    describe "disable" do
      it "should disable voter list " do
        voter_list = create(:voter_list, enabled: true)
        campaign = create(:campaign, :account => account, :active => true, voter_lists: [voter_list, create(:voter_list)])
        put :disable, campaign_id: campaign.id, id: voter_list.id, :api_key=> account.api_key, :format => "json"
        expect(response.body).to eq( "{\"message\":\"Voter List disabled\"}")
      end

    end

    describe "update" do
      it "should update voter list " do
        voter_list = create(:voter_list, enabled: true, name: "abc")
        campaign = create(:campaign, :account => account, :active => true, voter_lists: [voter_list, create(:voter_list)])
        put :update, campaign_id: campaign.id, id: voter_list.id, voter_list: {name: "xyz"}, :api_key=> account.api_key, :format => "json"
        expect(response.body).to eq( "{\"message\":\"Voter List updated\"}" )
        expect(voter_list.reload.name).to  eq('xyz')
      end
    end

    describe "destroy" do
      it "should update voter list " do
        voter_list = create(:voter_list, enabled: true, name: "abc")
        campaign = create(:campaign, :account => account, :active => true, voter_lists: [voter_list, create(:voter_list)])
        delete :destroy, campaign_id: campaign.id, id: voter_list.id, :api_key=> account.api_key, :format => "json"
        expect(response.body).to eq( "{\"message\":\"This operation is not permitted\"}")
      end
    end

    describe "create" do
      let(:campaign) do
        create(:campaign, {
          :account => account,
          :active => true
        })
      end

      let(:params) do
        {
          campaign_id: campaign.id,
          voter_list: {
            name: "abc.csv",
            separator: ",",
            headers: "[]",
            csv_to_system_map: "{\"Phone\": \"Phone\"}",
            s3path: "abc"
          },
          api_key: account.api_key,
          format: "json"
        }
      end

      context 'uploading a valid voter list' do
        let(:file_upload){ '/files/valid_voters_list.csv' }
        let(:csv_upload) do
          {
            'datafile' => fixture_file_upload(file_upload)
          }
        end

        it "renders voter_list attributes as json" do
          expect(Resque).to receive(:enqueue)
          post :create, params.merge(upload: csv_upload)
          expect(response.body).to match(/\{\"voter_list\":\{\"enabled\":true,\"id\":(.*),\"name\":\"abc.csv\"\}\}/)
        end
      end

      context 'uploading voter lists that are not CSV or TSV format' do
        let(:file_upload){ '/files/voter_list.xsl' }
        let(:csv_upload) do
          {
            'datafile' => fixture_file_upload(file_upload)
          }
        end
        it 'renders a json error message telling the consumer of the incorrect file format' do
          post :create, params.merge(upload: csv_upload)
          expect(response.body).to eq("{\"errors\":{\"base\":[\"Wrong file format. Please upload a comma-separated value (CSV) or tab-delimited text (TXT) file. If your list is in Excel format (XLS or XLSX), use \\\"Save As\\\" to change it to one of these formats.\"]}}")
        end
      end

      context 'upload requested when no file is submitted' do
        it 'renders a json error message telling the consumer to upload a file' do
          post :create, params.merge(upload: nil)
          expect(response.body).to eq("{\"errors\":{\"uploaded_file_name\":[\"can't be blank\"],\"base\":[\"Please upload a file.\"]}}")
        end
      end

    end

    describe 'column_mapping' do
      let(:campaign) do
        create(:campaign, {
          :account => account,
          :active => true
        })
      end

      let(:params) do
        {
          campaign_id: campaign.id,
          voter_list: {
            name: "abc.csv",
            separator: ",",
            headers: "[]",
            csv_to_system_map: "{\"Phone\": \"Phone\"}",
            s3path: "abc"
          },
          api_key: account.api_key,
          format: "html"
        }
      end

      context 'an empty file is uploaded' do
        let(:file_upload){ '/files/voter_list_empty.csv' }
        let(:csv_upload) do
          {
            'datafile' => fixture_file_upload(file_upload)
          }
        end

        it 'renders an error message telling the consumer that no headers were found in the file' do
          post :column_mapping, params.merge(upload: csv_upload)
          expect(response).to be_success
        end
      end

      context 'a file with only headers is uploaded' do
        let(:file_upload){ '/files/voter_list_only_headers.csv' }
        let(:csv_upload) do
          {
            'datafile' => fixture_file_upload(file_upload)
          }
        end

        it 'renders an error message telling the user that headers were found but no data rows' do
          post :column_mapping, params.merge(upload: csv_upload)
          expect(response).to be_success
        end
      end
    end

  end
  # render_views
  #
  # before :each do
  #   @current_user = create(:user)
  #   login_as @current_user
  # end
  #
  #
  # describe "voters list" do
  #   let(:csv_file_upload) { {"datafile" => fixture_file_upload("/files/valid_voters_list.csv")} }
  #
  #   before :each do
  #     @campaign = create(:predictive, :account => @current_user.account)
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
