require "spec_helper"

describe User do
  let(:user) { create(:user) }
  before(:each) do
    user
  end

  it "should not allow spambots" do
    u = User.new(:captcha =>"something")
    u.save
    u.errors[:base].should include("Spambots aren\'t welcome here")
  end

  it "creates a reset code" do
    Digest::SHA2.stub(:hexdigest).and_return('reset code')
    user.create_reset_code!
    user.password_reset_code.should == 'reset code'
  end

  it "clears the reset code" do
    user = create(:user, :password_reset_code => 'reset code')
    user.clear_reset_code
    user.password_reset_code.should be_nil
  end

  it "authenticates an email id with password" do
    user = create(:user, :email => "user@user.com")
    user.new_password = "abracadabra"
    user.save

    User.authenticate("user@user.com", "abracadabra").should == user
  end

  it "authenticates a User object with password" do
    user.new_password = "xyzzy123"
    user.save
    user.authenticate_with?("xyzzy123").should be_truthy
  end

  it "does not authenticate a User nil password" do
    user.authenticate_with?(nil).should be_falsey
  end

  it "delegates the domain to the account" do
    account = create(:account, :domain_name => 'foo.com')
    user.update_attribute(:account, account)
    user.domain.should == 'foo.com'
  end
end
