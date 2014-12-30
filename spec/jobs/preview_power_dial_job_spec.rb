require "spec_helper"

describe PreviewPowerDialJob do  
  it "should dial voter" do
    account        = create(:account)
    caller         = create(:caller, account: account)
    caller_session = create(:caller_session, caller: caller, campaign: caller.campaign)
    voter          = create(:voter, account: account, campaign: caller.campaign)

    expect(CallerSession).to receive_message_chain(:includes, :find_by_id).and_return(caller_session)
    
    expect(Twillio).to receive(:dial).with(voter.household, caller_session)
    
    PreviewPowerDialJob.new.perform(caller_session.id, voter.id)
  end
end