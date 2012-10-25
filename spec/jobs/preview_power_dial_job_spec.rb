require "spec_helper"

describe PreviewPowerDialJob do
  
  it "should dial voter" do
    account = Factory(:account)
    caller = Factory(:caller, account: account)
    caller_session = Factory(:caller_session, caller: caller)
    CallerSession.should_receive(:find_by_id_cached).and_return(caller_session)
    caller_session.should_receive(:funds_not_available?).and_return(false)
    caller_session.should_receive(:time_period_exceeded?).and_return(false)
    voter = Factory(:voter)
    Twillio.should_receive(:dial)
    PreviewPowerDialJob.new.perform(caller_session.id, voter.id)
  end
end