require "spec_helper"

describe Client::UsersController do
  it "resets a user's password" do
    user = Factory(:user)
    user.create_reset_code
    get :reset_password, :reset_code => user.password_reset_code
    flash[:error].should be_blank
    assigns(:user).should == user
  end

  it "updates the password" do
    user = Factory(:user)
    user.create_reset_code
    put :update_password, :user_id => user.id, :reset_code => user.password_reset_code, :password => 'new_password'
    flash[:error].should be_blank
    User.authenticate(user.email, 'new_password').should == user
    user.reload.password_reset_code.should be_nil
  end

  it "does not change the password if the reset code is invalid" do
    user = Factory(:user, :hashed_password => 'xyzzy', :salt => "abcdef")
    user.create_reset_code
    put :update_password, :user_id => user.id, :reset_code => 'xyz', :password => 'new_password'
    User.authenticate(user.email, 'new_password').should_not == user
    user.reload.password_reset_code.should_not be_nil
    user.hashed_password.should == "xyzzy"
    flash[:error].should_not be_blank
  end
end
