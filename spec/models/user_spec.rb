require "spec_helper"

describe User do
  before(:each) do
    Factory(:user)
  end

  it { should validate_uniqueness_of(:email).with_message(/is already in use/) }
end
