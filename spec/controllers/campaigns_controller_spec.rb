require "spec_helper"

describe CampaignsController do
  let(:account) { Factory(:account) }
  let(:user) { Factory(:user, :account => account) }
  let(:another_users_campaign) { Factory(:robo, :account => Factory(:account), :start_time => Time.new("2000-01-01 01:00:00"), :end_time => Time.new("2000-01-01 23:00:00")) }

  before(:each) do
    login_as user
  end

  describe "create a campaign" do

    xit "creates a new robo campaign" do
      manual_script = Factory(:script, :account => user.account, :robo => false)
      robo_script = Factory(:script, :account => user.account, :robo => true)
      lambda {
        post :create, :robo => {name: "Robo1", caller_id:  '0123456789'}
      }.should change(user.account.campaigns.active.robo, :size).by(1)
      user.account.campaigns.active.robo.last.script.should == robo_script
      response.should redirect_to campaigns_path
    end

    xit "creates a new robo campaign with the first active robo script by default" do
      deleted_script = Factory(:script, :account => user.account, :robo => true, :active => false)
      active_script = Factory(:script, :account => user.account, :robo => true, :active => true)
      lambda {
        post :create, :robo => {name: "Robo1", caller_id:  '0123456789'}
      }.should change(user.account.campaigns.active.robo, :size).by(1)
      user.account.campaigns.active.robo.last.script.should == active_script
    end

    describe "voicemails" do
      xit "creates a campaign with a voicemail" do
        voicemail = Factory(:script, :robo => true, :active => true, :for_voicemail => true, :name => "voicemail script")
        post :create, :robo => {:caller_id => "+3987", :robo => true, :voicemail_script_id => voicemail.id, name: "Robo1"}
        user.account.campaigns.active.robo.last.voicemail_script.should == voicemail
      end
    end

  end


  xit "lists robo campaigns" do
    robo_campaign = Factory(:robo, :account => user.account)
    manual_campaign = Factory(:preview, :account => user.account)
    get :index
    assigns(:campaigns).should == [robo_campaign]
  end

  xit "renders a campaign" do
    get :show, :id => Factory(:robo, :account => user.account).id
    response.code.should == '200'
  end

  xit "renders all the available voicemail scripts" do
    script = Factory(:script, :account => account, :for_voicemail => true, :robo => true)
    get :show, :id => Factory(:robo, :account => user.account).id
    assigns[:voicemails].should == [script]
  end

  xit "only provides robo scritps to select for a campaign" do
    robo_script = Factory(:script, :account => user.account, :robo => true)
    manual_script = Factory(:script, :account => user.account, :robo => false)
    get :show, :id => Factory(:robo, :account => user.account).id
    assigns(:scripts).should == [robo_script]
  end

  describe "update a campaign" do
    let(:default_script) { Factory(:script, :account => user.account, :robo => true, :active => true) }
    let(:campaign) { Factory(:robo, :account => user.account, :script => default_script) }

    xit "updates the campaign attributes" do
      new_script = Factory(:script, :account => user.account, :robo => true, :active => true, name: "new script")
      post :update, :id => campaign.id, :robo => {:name => "an impactful campaign", :script_id => new_script.id}
      campaign.reload.name.should == "an impactful campaign"
      campaign.reload.script.should == new_script
    end

    xit "assigns first of the robo scripts of the current user" do
      script = Factory(:script, :account => user.account, :robo => true, :active => true)
      post :update, :id => campaign.id, :robo => {}
      campaign.reload.script.should == default_script
    end

    xit "disables voters list which are not to be called" do
      voter_list1 = Factory(:voter_list, :campaign => campaign, :enabled => true)
      voter_list2 = Factory(:voter_list, :campaign => campaign, :enabled => false)
      post :update, :id => campaign.id, :voter_list_ids => [voter_list2.id]
      voter_list1.reload.should_not be_enabled
      voter_list2.reload.should be_enabled
    end

    xit "can update only campaigns owned by the user'" do
      post :update, :id => another_users_campaign.id
      response.status.should == 401
    end

    describe "voicemails" do
      let(:recording) { Factory(:recording) }

      xit "updates with voicemail attributes" do
        puts recording.id
        post :update, :id => campaign.id, :robo => {:answering_machine_detect => 1, :use_recordings => 1, :recording_id => recording.id}
        current_campaign = campaign.reload
        current_campaign.answering_machine_detect.should be_true
        current_campaign.use_recordings.should be_true
        current_campaign.recording.should == recording
      end

      xit "updates a campaign with a voicemail" do
        voicemail = Factory(:script, :robo => true, :active => true, :for_voicemail => true, :name => "voicemail script")
        post :update, :id=> campaign.id, :robo => {:caller_id => "+3987", :robo => true, :voicemail_script_id => voicemail.id}
        campaign.reload.voicemail_script.should == voicemail
      end

    end
  end

  xit "deletes a campaign" do
    campaign = Factory(:robo, :account => account, :robo => true)
    request.env['HTTP_REFERER'] = 'http://referer' if respond_to?(:request)
    delete :destroy, :id => campaign.id
    campaign.reload.should_not be_active
    response.should redirect_to(:back)
  end

  describe "dial statistics" do
    before :each do
      @campaign = Factory(:robo, :account => user.account)
    end

    xit "renders dial statistics for a campaign" do
      campaign = Factory(:robo, :account => user.account)
      get :dial_statistics, :id => campaign.id
      assigns(:campaign).should == campaign
      response.code.should == '200'
    end
  end

  def type_name
    'robo'
  end

end
