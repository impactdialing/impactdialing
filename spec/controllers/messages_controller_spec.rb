require 'spec_helper'

describe MessagesController do
  let(:account) { Factory(:account) }
  let(:user) { Factory(:user, :account => account) }

  before(:each) do
    login_as(user)
  end

  it "should create a message" do
    post :create, :script => {:name => 'some name'}
    assigns(:script).robo.should be_true
    assigns(:script).for_voicemail.should be_true
    assigns(:script).active.should be_true
    assigns(:script).account.should == account
  end

  it "should update a message" do
    script = Factory(:script, :robo => true, :for_voicemail => true)
    new_name = "new script name"
    post :update, :id => script.id, :script => { :name => new_name}
    assigns(:script).name.should == new_name
  end

  it "displays the message" do
    script = Factory(:script, :robo => true, :for_voicemail => true)
    script.robo_recordings << Factory(:robo_recording)
    get :show, :id => script.id
    response.should be_ok
  end
end
