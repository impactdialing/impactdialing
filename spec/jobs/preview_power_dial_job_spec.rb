require "spec_helper"

describe PreviewPowerDialJob do  
  it "should dial voter" do
    account = create(:account)
    caller = create(:caller, account: account)
    caller_session = create(:caller_session, caller: caller)
    expect(CallerSession).to receive(:find_by_id_cached).and_return(caller_session)
    voter = create(:voter)
    expect(Twillio).to receive(:dial)
    
    PreviewPowerDialJob.new.perform(caller_session.id, voter.id)
  end
end