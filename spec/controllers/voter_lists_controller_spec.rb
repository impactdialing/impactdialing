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
      @campaign = Factory(:campaign, :account => @current_user.account)
    end

    it "needs an uploaded file" do
      post :create, :campaign_id => @campaign.id
      flash[:error].should == ["Please click \"Choose file\" and select your list before clicking Upload."]
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
          post :create,
               :campaign_id => @campaign.id,
               :upload => csv_file_upload
        end

        it "sets the session to the new voter list entry" do
          session[:voters_list_upload].should_not be_empty
        end

        it "saves the uploaded csv" do
          File.should exist("#{Rails.root}/tmp/#{session[:voters_list_upload]['filename']}")
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

        describe "import" do
          describe "requirements" do
            it "needs a list name" do
              import :voter_list_name => ""
              request.flash.now[:error].first.should include "Name can't be blank"
              response.should render_template "column_mapping"
            end

            it "should not save a list if the user already has a list with the same name" do
              Factory(:voter_list, :account => @current_user.account, :campaign_id => @campaign.id, :name => "abcd")
              import :voter_list_name => "abcd"
              response.flash.now[:error].first.should include "Name for this list is already taken."
              response.should render_template "column_mapping"
            end
          end

          describe "after import" do
            it "saves all the voters in the csv according to the mappings" do
              Voter.delete_all
              import
              Voter.count.should == 2
              Voter.first.Phone.should == "1234567895"
              Voter.first.LastName.should == "Bar"
            end

            it "removes the temporary file from disk" do
              temp_filename = "#{Rails.root}/tmp/#{session[:voters_list_upload]['filename']}"
              import
              File.should_not exist(temp_filename)
              session[:voters_list_upload].should be_blank
            end
          end

          describe "custom fields" do
            let(:csv_file_upload) { {"datafile" => fixture_file_upload("/files/voters_custom_fields_list.csv")} }

            it "creates previously uncreated custom columns" do
              custom_field = "Custom"
              Voter.delete_all
              import({:json_csv_column_headers => ["Phone", "Custom"].to_json, :csv_to_system_map =>{"Phone"=>"Phone", custom_field=>custom_field}})
              CustomVoterField.all.size.should == 1
              custom_fields = Voter.all.collect{|voter| voter.get_attribute(custom_field)}
              custom_fields.length.should eq(2)
              custom_fields.should include("Foo")
              custom_fields.should include("Bar")              
            end
          end
        end
      end

      describe "malformed csv file" do
        before :each do
          session[:voters_list_upload] = nil
          post :create,
               :campaign_id => @campaign.id,
               :upload => {"datafile" => fixture_file_upload("/files/invalid_voters_list.csv")}
          import
        end

        it "should flash an error" do
          flash[:error].join.should include "Invalid CSV file"
          response.code.should == "302"
        end

        it "should not save the voters list entry" do
          VoterList.all.should be_empty
        end
      end
    end
  end
end
