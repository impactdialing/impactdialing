require "spec_helper"

describe PreviewPowerDialJob do
  
  it "should dial voter" do
    account = create(:account)
    caller = create(:caller, account: account)
    caller_session = create(:caller_session, caller: caller)
    expect(CallerSession).to receive(:find_by_id_cached).and_return(caller_session)
    expect(caller_session).to receive(:funds_not_available?).and_return(false)
    expect(caller_session).to receive(:time_period_exceeded?).and_return(false)
    voter = create(:voter)
    expect(Twillio).to receive(:dial)
    PreviewPowerDialJob.new.perform(caller_session.id, voter.id)
  end
end