require "spec_helper"

describe CampaignsController do
  let(:account) { Factory(:account) }
  let(:user) { Factory(:user, :account => account) }
  let(:another_users_campaign) { Factory(:campaign, :account => Factory(:account), :start_time => Time.new("2000-01-01 01:00:00"), :end_time => Time.new("2000-01-01 23:00:00")) }

  before(:each) do
    login_as user
  end

  describe "create a campaign" do

    it "creates a new robo campaign" do
      manual_script = Factory(:script, :account => user.account, :robo => false)
      robo_script = Factory(:script, :account => user.account, :robo => true)
      lambda {
        post :create, :campaign => {:caller_id => '0123456789'}
      }.should change(user.account.campaigns.active.robo, :size).by(1)
      user.account.campaigns.active.robo.last.script.should == robo_script
      response.should redirect_to campaigns_path
    end

    it "creates a new robo campaign with the first active robo script by default" do
      deleted_script = Factory(:script, :account => user.account, :robo => true, :active => false)
      active_script = Factory(:script, :account => user.account, :robo => true, :active => true)
      lambda {
        post :create, :campaign => {:caller_id => '0123456789'}
      }.should change(user.account.campaigns.active.robo, :size).by(1)
      user.account.campaigns.active.robo.last.script.should == active_script
    end

    describe "voicemails" do
      it "creates a campaign with a voicemail" do
        voicemail = Factory(:script, :robo => true, :active => true, :for_voicemail => true, :name => "voicemail script")
        post :create, :campaign => {:caller_id => "+3987", :robo => true, :voicemail_script => voicemail}
        user.account.campaigns.active.robo.last.voicemail_script.should == voicemail
      end
    end

  end


  it "lists robo campaigns" do
    robo_campaign = Factory(:campaign, :account => user.account, :robo => true)
    manual_campaign = Factory(:campaign, :account => user.account, :robo => false)
    get :index
    assigns(:campaigns).should == [robo_campaign]
  end

  it "renders a campaign" do
    get :show, :id => Factory(:campaign, :account => user.account, :robo => true).id
    response.code.should == '200'
  end

  it "renders all the available voicemail scripts" do
    script = Factory(:script, :account => account, :for_voicemail => true, :robo => true)
    get :show, :id => Factory(:campaign, :account => user.account, :robo => true).id
    assigns[:voicemails].should == [script]
  end

  it "only provides robo scritps to select for a campaign" do
    robo_script = Factory(:script, :account => user.account, :robo => true)
    manual_script = Factory(:script, :account => user.account, :robo => false)
    get :show, :id => Factory(:campaign, :account => user.account, :robo => true).id
    assigns(:scripts).should == [robo_script]
  end

  describe "update a campaign" do
    let(:default_script) { Factory(:script, :account => user.account, :robo => true, :active => true) }
    let(:campaign) { Factory(:campaign, :account => user.account, :script => default_script, :robo =>true) }

    it "updates the campaign attributes" do
      new_script = Factory(:script, :account => user.account, :robo => true, :active => true)
      post :update, :id => campaign.id, :campaign => {:name => "an impactful campaign", :script => new_script}
      campaign.reload.name.should == "an impactful campaign"
      campaign.reload.script.should == new_script
    end

    it "assigns first of the robo scripts of the current user" do
      script = Factory(:script, :account => user.account, :robo => true, :active => true)
      post :update, :id => campaign.id, :campaign => {}
      campaign.reload.script.should == default_script
    end

    it "disables voters list which are not to be called" do
      voter_list1 = Factory(:voter_list, :campaign => campaign, :enabled => true)
      voter_list2 = Factory(:voter_list, :campaign => campaign, :enabled => false)
      post :update, :id => campaign.id, :voter_list_ids => [voter_list2.id]
      voter_list1.reload.should_not be_enabled
      voter_list2.reload.should be_enabled
    end

    it "can update only campaigns owned by the user'" do
      post :update, :id => another_users_campaign.id
      response.status.should == 401
    end

    describe "voicemails" do
      let(:recording) { Factory(:recording) }

      it "updates with voicemail attributes" do
        post :update, :id => campaign.id, :campaign => {:answering_machine_detect => true, :use_recordings => true, :recording_id => recording.id}
        current_campaign = campaign.reload
        current_campaign.answering_machine_detect.should be_true
        current_campaign.use_recordings.should be_true
        current_campaign.recording.should == recording
      end

      it "updates a campaign with a voicemail" do
        #campaign = Factory(:campaign, :robo => true)
        voicemail = Factory(:script, :robo => true, :active => true, :for_voicemail => true, :name => "voicemail script")
        post :update, :id=> campaign.id, :campaign => {:caller_id => "+3987", :robo => true, :voicemail_script => voicemail}
        campaign.reload.voicemail_script.should == voicemail
      end

    end
  end

  it "deletes a campaign" do
    campaign = Factory(:campaign, :account => account, :robo => true)
    request.env['HTTP_REFERER'] = 'http://referer' if respond_to?(:request)
    delete :destroy, :id => campaign.id
    campaign.reload.should_not be_active
    response.should redirect_to(:back)
  end

  describe "dial statistics" do
    before :each do
      @campaign = Factory(:campaign, :account => user.account)
    end

    it "renders dial statistics for a campaign" do
      campaign = Factory(:campaign, :account => user.account)
      get :dial_statistics, :id => campaign.id
      assigns(:campaign).should == campaign
      response.code.should == '200'
    end
  end

  def type_name
    'campaign'
  end

  it_should_behave_like 'all controllers of deletable entities'
end
