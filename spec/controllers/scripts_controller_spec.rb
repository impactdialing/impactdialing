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
      robo_script = Factory(:script, :account => user.account, :active => true, :robo => true)
      manual_script = Factory(:script, :account => user.account, :active => true, :robo => false)
      get :index
      assigns(:scripts).should == [robo_script]
    end

    it_should_behave_like 'all controllers of deletable entities'

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
