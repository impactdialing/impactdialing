require 'rails_helper'

describe Client::UsersController, :type => :controller do
  before(:each) do
    request.env['HTTP_REFERER'] = 'http://referer'
  end

  it 'creates a user' do
    valid_attrs = {
      user: {
        email: Forgery(:email).address,
        new_password: 'secret',
        fname: Forgery(:name).first_name,
        lname: Forgery(:name).last_name,
        phone: Forgery(:address).phone
      },
      domain_name: 'impactdialing.com'
    }
    expect{
      post :create, valid_attrs
    }.to change{User.count}.by 1
    new_user = User.last
    [:email, :fname, :lname, :phone].each do |attr|
      expect(new_user[attr]).to eq valid_attrs[:user][attr]
    end
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

  describe 'invite' do
    let(:admin){ create(:user) }
    let(:account){ admin.account }
    let(:email){ 'foo@test.com' }
    let(:new_user){ account.users.last }
    let(:std_params) do
      {
        user: {
          role: 'admin'
        }
      }
    end
    before do
      login_as(admin)
    end
    context 'with valid params' do
      it 'creates a new user' do
        expect {
          post :invite, std_params.merge(email: email)
        }.to change(account.users.reload, :count).by(1)
        expect(account.users.reload.last.email).to eq(email)
      end
      it 'sends the new user an invitation email' do
        post :invite, std_params.merge(email: email)
        expect([:resque, :general]).to have_queued(DeliverInvitationEmailJob).with(new_user.id, admin.id)
      end
      it 'redirects to :back' do
        post :invite, std_params.merge(email: email)
        expect(response).to redirect_to(:back)
      end
    end
    context 'with invalid params' do
      it 'user already invited for this account' do
        create(:user, account: account, email: email)
        post :invite, std_params.merge(email: email)
        expect(flash[:error]).to eq ["#{email} has already been invited."]
      end
      it 'user already exists in another account' do
        create(:user, email: email)
        post :invite, std_params.merge(email: email)
        expect(flash[:error]).to eq ["#{email} is already part of a different account."]
      end
      it 'user is just invalid' do
        invalid_user = User.new(email: '', new_password: 'k34jkk32j4k', role: 'admin')
        invalid_user.valid?
        post :invite, std_params.merge(email: '')
        expect(flash[:error]).to eq invalid_user.errors.full_messages
      end
    end
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
