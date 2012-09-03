require "spec_helper"

describe ClientController do
  before(:each) do
    request.env['HTTP_REFERER'] = 'http://referer'
  end

  describe "when not logged in" do
    it "creates a new user with the appropriate domain" do
      request.should_receive(:domain).and_return('domain.com')
      lambda {
        post :user_add, :user => { :email => 'email@example.com', :new_password => 'something' }, :tos => true
      }.should change(User, :count).by(1)
      User.last.account.domain.should == 'domain.com'
    end
  end

  context "when logged in" do
    let(:user) { Factory(:user) }

    before :each do
      login_as user
    end

    describe "and attempt to login yet again" do
      it "redirects to 'add new client'" do
        get "login"
        response.should redirect_to "/client/user_add"
      end
    end

    describe "reports" do
      it "shows only manual campaigns" do
        campaign = Factory(:preview, :account => user.account)
        Factory(:robo, :account => user.account)
        get :reports
        assigns(:campaigns).should == [campaign]
      end
    end



    it "deleting a script redirects to the referer" do
      entity = Factory(:script, :account => user.account, :active => true)
      post "script_delete", :id => entity.id
      entity.reload.active.should be_false
      response.should redirect_to :back
    end
    
    it "should not delete a script assigned to a active campaign" do
      script = Factory(:script, account: user.account, robo: true, active: true)
      campaign =  Factory(:predictive, active: true, script_id: script.id, account: user.account)
      post "script_delete", :id => script.id
      script.reload.active.should be_true
      response.should redirect_to :back
    end
    

  end
end
