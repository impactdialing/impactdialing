require "spec_helper"

describe PreviewPowerDialJob do  
  it "should dial voter" do
    account        = create(:account)
    caller         = create(:caller, account: account)
    caller_session = create(:caller_session, caller: caller)
    phone          = Forgery(:address).phone

    expect(CallerSession).to receive(:find_by_id_cached).and_return(caller_session)
    
    expect(Twillio).to receive(:dial).with(phone, caller_session)
    
    PreviewPowerDialJob.new.perform(caller_session.id, phone)
  end
end