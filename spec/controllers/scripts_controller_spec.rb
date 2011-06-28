require "spec_helper"

describe ScriptsController do
  let(:user) { Factory(:user) }

  before(:each) do
    login_as user
  end

  def type_name
    'script'
  end

  it "defaults to robo script" do
    get :new
    assigns(:script).robo.should be_true
  end

  it "lists robo scripts" do
    robo_script = Factory(:script, :user => user, :active => true, :robo => true)
    manual_script = Factory(:script, :user => user, :active => true, :robo => false)
    get :index
    assigns(:scripts).should == [robo_script]
  end



  it_should_behave_like 'all controllers of deletable entities'

  it "lists active scripts" do
    active_script = Factory(:script, :user => user, :active => true, :robo => true)
    inactive_script = Factory(:script, :user => user, :active => false, :robo => true)
    get :index
    assigns(:scripts).should == [active_script]
  end

  it "creates a new script" do
    get :new
    assigns(:script).should be
    assigns(:script).name.should == 'Untitled Script'
  end


end
