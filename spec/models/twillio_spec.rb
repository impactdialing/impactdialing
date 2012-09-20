require 'spec_helper'

describe Twillio do
  
  it "should setup_call by creating call attempt " do
    campaign = Factory(:campaign)
    voter = Factory(:voter, campaign: campaign)
    caller_session = Factory(:caller_session, campaign: campaign)    
    Twillio.setup_call(voter, caller_session, campaign)
    CallAttempt.first.voter_id.should eq(voter.id)
  end
  
  it "should setup_call by by loading call attempt into redis " do
    campaign = Factory(:campaign)
    voter = Factory(:voter, campaign: campaign)
    caller_session = Factory(:caller_session, campaign: campaign)    
    RedisCallAttempt.should_receive(:load_call_attempt_info)
    Twillio.setup_call(voter, caller_session, campaign)
  end

  it "should setup_call by changing voter info " do
    campaign = Factory(:campaign)
    voter = Factory(:voter, campaign: campaign)
    caller_session = Factory(:caller_session, campaign: campaign)        
    RedisVoter.should_receive(:setup_call)
    Twillio.setup_call(voter, caller_session, campaign)
  end
  
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
