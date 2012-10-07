require "spec_helper"

describe PreviewPowerDialJob do
  
  it "should dial voter" do
    caller_session = Factory(:caller_session)
    voter = Factory(:voter)
    Twillio.should_receive(:dial)
    PreviewPowerDialJob.new.perform(caller_session.id, voter.id)
  end
end