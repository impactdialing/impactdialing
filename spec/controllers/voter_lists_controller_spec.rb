require "spec_helper"

describe VoterListsController do
  include ActionController::TestProcess
  integrate_views

  before :each do
    @current_user = Factory(:user)
    login_as @current_user
  end

  describe "voters list" do
    let(:csv_file_upload) { {"datafile" => fixture_file_upload("files/voters_list.csv")} }
    before :each do
      @campaign = Factory(:campaign, :user_id => session[:user])
    end

    it "needs an uploaded file" do
      post :create, :campaign_id => @campaign.id
      flash[:error].should == ["You must select a file to upload"]
    end

    describe "create voter list" do
      before :each do
        session[:voters_list_upload] = nil
        post :create,
             :campaign_id => @campaign.id,
             :upload      => csv_file_upload
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

      describe "select the mappings" do
        def add_to_db
          post :add_to_db,
               :separator         => ",",
               :voter_list_name   => "voter list name",
               :campaign_id       => @campaign.id,
               :csv_to_system_map => {
                   "Phone" => "Phone",
                   "LAST"  =>"LastName"
               }
        end

        it "needs a list name" do
          post :add_to_db,
               :separator         => ",",
               :campaign_id       => @campaign.id,
               :csv_to_system_map => {
                   "Phone" => "Phone",
                   "LAST"  =>"LastName"
               }
          flash[:error].should include "Name can't be blank"
        end
        it "should not save a list if the user already has a list with the same name" do
          Factory(:voter_list, :user_id => @current_user.id, :campaign_id => @campaign.id, :name => "abcd")
          post :add_to_db,
               :separator         => ",",
               :campaign_id       => @campaign.id,
               :csv_to_system_map => {
                   "Phone" => "Phone",
                   "LAST"  =>"LastName"
               },
              :voter_list_name => "abcd"
          flash[:error].should include "Name for this voter list is already taken"
          response.should redirect_to campaign_view_path(@campaign.id)
        end
        it "saves all the voters in the csv according to the mappings" do
          Voter.delete_all
          add_to_db()
          Voter.count.should == 1
          Voter.first.Phone.should == "1234567895"
          Voter.first.LastName.should == "Bar"
        end
        it "removes the temporary file from disk" do
          temp_filename = "#{Rails.root}/tmp/#{session[:voters_list_upload]['filename']}"
          add_to_db()
          File.should_not exist(temp_filename)
          session[:voters_list_upload].should be_blank
        end
      end
    end
  end
end