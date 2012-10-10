require 'spec_helper'

describe Twillio do
  
  
  it "should setup_call by changing voter info " do
    campaign = Factory(:campaign)
    voter = Factory(:voter, campaign: campaign)
    caller_session = Factory(:caller_session, campaign: campaign)          
    Twillio.setup_call(voter, caller_session, campaign)
    Call.all.size.should eq(1)
  end
  
  it "caller sessions update in progress should be updated " do
    campaign = Factory(:campaign)
    voter = Factory(:voter, campaign: campaign)
    caller_session = Factory(:caller_session, campaign: campaign)          
    Twillio.setup_call(voter, caller_session, campaign)
    caller_session.attempt_in_progress.should_not be_nil
  end
  
  
end
