require "spec_helper"

describe Client::UsersController, :type => :controller do
  before(:each) do
    request.env['HTTP_REFERER'] = 'http://referer'
  end

  it "resets a user's password" do
    user = create(:user)
    user.create_reset_code!
    get :reset_password, :reset_code => user.password_reset_code
    expect(flash[:error]).to be_blank
    expect(assigns(:user)).to eq(user)
  end

  it "updates the password" do
    user = create(:user)
    user.create_reset_code!
    put :update_password, :user_id => user.id, :reset_code => user.password_reset_code, :password => 'new_password'
    expect(flash[:error]).to be_blank
    expect(User.authenticate(user.email, 'new_password')).to eq(user)
    expect(user.reload.password_reset_code).to be_nil
  end


  it "logins the user" do
    user = create(:user)
    user.create_reset_code!
    put :update_password, :user_id => user.id, :reset_code => user.password_reset_code, :password => 'new_password'
    expect(flash[:error]).to be_blank
    expect(User.authenticate(user.email, 'new_password')).to eq(user)
    expect(session[:user]).to eq(user.id)
  end

  it "does not change the password if the reset code is invalid" do
    user = create(:user, :new_password => 'xyzzy')
    user.create_reset_code!
    put :update_password, :user_id => user.id, :reset_code => 'xyz', :password => 'new_password'
    expect(User.authenticate(user.email, 'new_password')).not_to eq(user)
    expect(user.reload.password_reset_code).not_to be_nil
    expect(user.authenticate_with?("xyzzy")).to be_truthy
    expect(flash[:error]).not_to be_blank
  end

  it "invites a new user to the current user's account" do
    user = create(:user).tap{|u| login_as u}
    expect(Resque).to receive(:enqueue)
    expect {
      post :invite, :email => 'foo@bar.com', user: {role: "admin"}
    }.to change(user.account.users.reload, :count).by(1)
    expect(user.account.users.reload.last.email).to eq('foo@bar.com')
    expect(response).to redirect_to(:back)
  end

  describe 'destroy' do
    it "deletes a  user" do
      account = create(:account)
      user = create(:user, :email => 'foo@bar.com', :account => account)
      current_user = create(:user, :account => account).tap{|u| login_as u}
      post :destroy, :id => user.id
      expect(User.find_by_id(user.id)).not_to be
    end
  end
end
