require "spec_helper"

describe ClientController do

  describe "when not logged in" do
    it "creates a new user with the appropriate domain" do
      request.stub!(:domain).and_return('domain.com')
      lambda {
        post :user_add, :user => { :email => 'email@example.com', :new_password => 'something' }, :tos => true
      }.should change(User, :count).by(1)
      User.last.domain.should == 'domain.com'
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
        campaign = Factory(:campaign, :user => user, :robo => false)
        Factory(:campaign, :user => user, :robo => true)
        get :reports
        assigns(:campaigns).should == [campaign]
      end
    end

    describe "fields" do
      it "shows original and custom fields" do
        field = Factory(:custom_voter_field, :user => user, :name => "Foo")
        script = Factory(:script, :user => user)
        get :script_add, :id => script.id
        assigns(:fields).should include(field.name)
      end

      it "doesn't add custom fields on a new script" do
        get :script_add
        assigns(:fields).should == ["CustomID","FirstName","MiddleName","LastName","Suffix","Age","Gender","Phone","Email"]
      end
    end

    it "lists all manual scripts" do
      robo_script = Factory(:script, :user => user, :robo => true)
      manual_script = Factory(:script, :user => user, :robo => false)
      get :scripts
      assigns(:scripts).should == [manual_script]
    end

    it "deleting a script redirects to the referer" do
      request.env['HTTP_REFERER'] = 'http://referer/'
      entity = Factory(:script, :user => user, :active => true)
      post "script_delete", :id => entity.id
      entity.reload.active.should be_false
      response.should redirect_to :back
    end

    describe 'callers' do
      render_views

      it "shows" do
        get :callers
        response.code.should == '200'
      end
    end
  end
end
