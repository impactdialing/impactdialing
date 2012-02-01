require 'spec_helper'

describe MessagesController do
  let(:user) { Factory(:user) }

  before(:each) do
    login_as(user)
  end

  it "should create a message" do
    post :create, :script => {:name => 'some name'}
    assigns(:script).robo.should be_true
    assigns(:script).for_voicemail.should be_true
  end

  it "displays the message" do
    script = Factory(:script, :robo => true, :for_voicemail => true)
    script.robo_recordings << Factory(:robo_recording)
    get :show, :id => script.id
    response.should be_ok
  end
end
