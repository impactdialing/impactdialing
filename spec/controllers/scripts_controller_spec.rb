require "spec_helper"

describe ScriptsController do
  context 'when logged in' do
    let(:user) { Factory(:user) }

    before(:each) do
      login_as user
    end

    def type_name
      'script'
    end

    it "defaults to robo script" do
      get :new
      assigns(:script).should be_robo
      assigns(:script).robo_recordings.should have(1).thing
    end

    it "lists robo scripts" do
      manual_script = Factory(:script, :account => user.account, :active => true, :robo => false)
      interactive_script = Factory(:script, :account => user.account, :active => true, :robo => true)
      non_interactive_script = Factory(:script, :account => user.account, :active => true, :robo => true, :for_voicemail => true)
      get :index
      assigns(:scripts).should == [interactive_script, non_interactive_script]
    end
    
    it "lists deleted entities" do
      deleted_entity = Factory(:script, :account => user.account, :active => false, robo:true)
      active_entity = Factory(type_name, :account => user.account, :active => true, robo:true)
      get :deleted
      assigns(:scripts).should == [deleted_entity]
    end
    

    it "lists active scripts" do
      active_script = Factory(:script, :account => user.account, :active => true, :robo => true)
      inactive_script = Factory(:script, :account => user.account, :active => false, :robo => true)
      get :index
      assigns(:scripts).should == [active_script]
    end

    it "creates a new script" do
      get :new
      assigns(:script).should be
      assigns(:script).name.should == 'Untitled Script'
    end
  end

  context "when not logged in" do
    it "redirects to the login page" do
      get :index
      response.should redirect_to login_path
    end
  end
end
