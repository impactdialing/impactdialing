require "spec_helper"

describe User, :type => :model do
  let(:user) { create(:user) }
  before(:each) do
    user
  end

  it "should not allow spambots" do
    u = User.new(:captcha =>"something")
    u.save
    expect(u.errors[:base]).to include("Spambots aren\'t welcome here")
  end

  it "creates a reset code" do
    allow(Digest::SHA2).to receive(:hexdigest).and_return('reset code')
    user.create_reset_code!
    expect(user.password_reset_code).to eq('reset code')
  end

  it "clears the reset code" do
    user = create(:user, :password_reset_code => 'reset code')
    user.clear_reset_code
    expect(user.password_reset_code).to be_nil
  end

  it "authenticates an email id with password" do
    user = create(:user, :email => "user@user.com")
    user.new_password = "abracadabra"
    user.save

    expect(User.authenticate("user@user.com", "abracadabra")).to eq(user)
  end

  it "authenticates a User object with password" do
    user.new_password = "xyzzy123"
    user.save
    expect(user.authenticate_with?("xyzzy123")).to be_truthy
  end

  it "does not authenticate a User nil password" do
    expect(user.authenticate_with?(nil)).to be_falsey
  end

  it "delegates the domain to the account" do
    account = create(:account, :domain_name => 'foo.com')
    user.update_attribute(:account, account)
    expect(user.domain).to eq('foo.com')
  end
end
