require "spec_helper"

describe CallerSession do
  
  it "should start a call in initial state" do
    caller_session = Factory(:caller_session)
    caller_session.state.should eq('initial')
  end
  
  describe "Campaign time period exceeded" do
    before(:each) do
      @caller = Factory(:caller)
      @script = Factory(:script)
      @campaign =  Factory(:campaign, script: @script, start_time:  Time.new(2011, 1, 1, 9, 0, 0), end_time:  Time.new(2011, 1, 1, 21, 0, 0))    
    end
    
    it "should move caller session campaign_time_period_exceeded state" do
      caller_session = Factory(:caller_session, caller: @caller, on_call: true, available_for_call: true, campaign: @campaign)
      # @campaign.should_receive(:time_period_exceeded?).and_return(true)
      caller_session.start_conference!
      caller_session.state.should eq('')
    end
    
    
    
  end
  
end