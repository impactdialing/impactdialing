require "spec_helper"

describe ScriptsController do
  let(:user) { Factory(:user) }

  before(:each) do
    login_as user
  end

  def type_name
    'script'
  end

  it_should_behave_like 'all controllers of deletable entities'

  it "lists all scripts" do
    active_script = Factory(:script, :user => user, :active => true)
    inactive_script = Factory(:script, :user => user, :active => false)
    get :index
    assigns(:scripts).should == [active_script]
  end
end
