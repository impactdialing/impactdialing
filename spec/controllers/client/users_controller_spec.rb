require "spec_helper"

describe Client::UsersController do
  before(:each) do
    request.env['HTTP_REFERER'] = 'http://referer'
  end

  it "resets a user's password" do
    user = create(:user)
    user.create_reset_code!
    get :reset_password, :reset_code => user.password_reset_code
    flash[:error].should be_blank
    assigns(:user).should == user
  end

  it "updates the password" do
    user = create(:user)
    user.create_reset_code!
    put :update_password, :user_id => user.id, :reset_code => user.password_reset_code, :password => 'new_password'
    flash[:error].should be_blank
    User.authenticate(user.email, 'new_password').should == user
    user.reload.password_reset_code.should be_nil
  end


  it "logins the user" do
    user = create(:user)
    user.create_reset_code!
    put :update_password, :user_id => user.id, :reset_code => user.password_reset_code, :password => 'new_password'
    flash[:error].should be_blank
    User.authenticate(user.email, 'new_password').should == user
    session[:user].should eq(user.id)
  end

  it "does not change the password if the reset code is invalid" do
    user = create(:user, :new_password => 'xyzzy')
    user.create_reset_code!
    put :update_password, :user_id => user.id, :reset_code => 'xyz', :password => 'new_password'
    User.authenticate(user.email, 'new_password').should_not == user
    user.reload.password_reset_code.should_not be_nil
    user.authenticate_with?("xyzzy").should be_true
    flash[:error].should_not be_blank
  end

  it "invites a new user to the current user's account" do
    user = create(:user).tap{|u| login_as u}
    Resque.should_receive(:enqueue)
    lambda {
      post :invite, :email => 'foo@bar.com', user: {role: "admin"}
    }.should change(user.account.users.reload, :count).by(1)
    user.account.users.reload.last.email.should == 'foo@bar.com'
    response.should redirect_to(:back)
  end

  describe 'destroy' do
    it "deletes a  user" do
      account = create(:account)
      user = create(:user, :email => 'foo@bar.com', :account => account)
      current_user = create(:user, :account => account).tap{|u| login_as u}
      post :destroy, :id => user.id
      User.find_by_id(user.id).should_not be
    end
  end
end
