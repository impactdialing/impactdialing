require "spec_helper"

describe Admin::CallersController do
  before(:each) do
    controller.should_receive(:authenticate).and_return(true)
  end

  it "restores a deleted caller" do
    caller_object = Factory(:caller, :active => false)
    put :restore, :caller_id => caller_object.id
    caller_object.reload.should be_active
    response.should redirect_to admin_callers_path
  end



end
