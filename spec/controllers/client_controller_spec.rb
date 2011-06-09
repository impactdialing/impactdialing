require "spec_helper"

describe ClientController do
  include ActionController::TestProcess

  describe "when not logged in" do
    it "redirects to the login page" do
      get "/client"
      response.should redirect_to "/client/login"
    end
  end


  describe "when logged in" do
    before :each do
      login_as Factory(:user)
    end

    describe "and attempt to login yet again" do
      it "redirects to 'add new client'" do
        get "login"
        response.should redirect_to "/client/user_add"
      end
    end

    describe 'new campaign' do
      it "creates a new campaign & redirects to campaign view" do
        lambda {
          get :campaign_new
        }.should change(Campaign, :count).by(1)
        response.should redirect_to "/client/campaign_view/#{Campaign.last.id}"
      end

      describe "upload voters list" do
        let(:csv_file_upload) { {"datafile" => fixture_file_upload("files/voters_list.csv")} }
        before :each do
          @campaign = Factory(:campaign, :user_id => session[:user])
        end

        it "needs an uploaded file" do
          post :voter_upload, :id => @campaign.id
          flash[:error].should == "You must select a file to upload"
        end

        it "needs a list name" do
          post :voter_upload, :id => @campaign.id,
               :upload => csv_file_upload
          flash[:error].should include "Name can't be blank"
        end

        it "creates a voter list entry" do
          lambda {
            Campaign.should_receive(:find_by_id_and_user_id).
                with(@campaign.id.to_s, session[:user]).
                and_return(@campaign)

            @campaign.should_receive(:voter_upload).with(
                csv_file_upload, session[:user], ",", anything()
            )
            post :voter_upload,
                 :id => @campaign.id,
                 :upload => csv_file_upload,
                 :list_name => "foobar"
            flash[:error].should be_blank
            response.code.should == "200"
          }.should change(VoterList, :count)
        end
      end
    end
  end
end
