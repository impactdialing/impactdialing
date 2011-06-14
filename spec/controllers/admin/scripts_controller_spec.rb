require "spec_helper"

describe Admin::ScriptsController do
  before(:each) do
    controller.should_receive(:authenticate).and_return(true)
  end

  it "restores a deleted script" do
    script = Factory(:script, :active => false)
    put :restore, :script_id => script.id
    script.reload.should be_active
    response.should redirect_to admin_scripts_path
  end
end
