require "spec_helper"

describe Client::UsersController do
  it "resets a user's password" do
    user = Factory(:user)
    user.create_reset_code
    get :reset_password, :reset_code => user.password_reset_code
    assigns(:user).should == user
  end

  it "updates the password" do
    user = Factory(:user)
    user.create_reset_code
    put :update_password, :user_id => user.id, :reset_code => user.password_reset_code, :password => 'new_password', :confirm_password => 'new_password'
    User.authenticate(user.email, 'new_password').should == user
    user.reload.password_reset_code.should be_nil
  end
end
