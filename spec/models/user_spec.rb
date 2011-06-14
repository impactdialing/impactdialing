require "spec_helper"

describe User do
  before(:each) do
    Factory(:user)
  end

  it { should validate_uniqueness_of(:email).with_message(/is already in use/) }

  it "creates a reset code" do
    Digest::SHA2.stub!(:hexdigest).and_return('reset code')
    user = Factory(:user)
    user.create_reset_code
    user.password_reset_code.should == 'reset code'
  end

  it "clears the reset code" do
    user = Factory(:user, :password_reset_code => 'reset code')
    user.clear_reset_code
    user.password_reset_code.should be_nil
  end
end
