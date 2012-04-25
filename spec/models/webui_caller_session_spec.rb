require "spec_helper"

describe WebuiCallerSession do
  
  describe "caller reassigned " do
    
    before(:each) do
      @script = Factory(:script)
      @campaign =  Factory(:preview, script: @script)    
      @callers_campaign =  Factory(:preview, script: @script)    
      @caller = Factory(:caller, campaign: @callers_campaign)
    end
    
    it "set state to connected when campaign changes" do
      caller_session = Factory(:webui_caller_session, caller: @caller, on_call: true, available_for_call: true, campaign: @campaign)
      caller_session.should_receive(:account_not_activated?).and_return(false)
      caller_session.should_receive(:subscription_limit_exceeded?).and_return(false)
      caller_session.should_receive(:time_period_exceeded?).and_return(false)
      caller_session.should_receive(:is_on_call?).and_return(false)
      # caller_session.should_receive(:disconnected?).and_return(false)      
      caller_session.should_receive(:caller_reassigned_to_another_campaign?).and_return(true)                  
      caller_session.start_conf!
      caller_session.campaign.should eq(@caller.campaign)
      caller_session.state.should eq("connected")          
    end
    
    it "shouild render correct twiml" do
      caller_session = Factory(:webui_caller_session, caller: @caller, on_call: true, available_for_call: true, campaign: @campaign)
      caller_session.should_receive(:account_not_activated?).and_return(false)
      caller_session.should_receive(:subscription_limit_exceeded?).and_return(false)
      caller_session.should_receive(:time_period_exceeded?).and_return(false)
      caller_session.should_receive(:is_on_call?).and_return(false)
      # caller_session.should_receive(:disconnected?).and_return(false)      
      caller_session.should_receive(:caller_reassigned_to_another_campaign?).and_return(true)            
      caller_session.start_conf!
      caller_session.render.should eq("<?xml version=\"1.0\" encoding=\"UTF-8\"?><Response><Dial hangupOnStar=\"true\" action=\"https://3ngz.localtunnel.com:3000/caller/#{@caller.id}/flow?event=pause_conf&amp;session_id=#{caller_session.id}\"><Conference startConferenceOnEnter=\"false\" endConferenceOnExit=\"true\" beep=\"true\" waitUrl=\"https://3ngz.localtunnel.com:3000/hold_call?version=2012-02-16+10%3A20%3A07+%2B0530\" waitMethod=\"GET\"></Conference></Dial></Response>")          
    end
    
  end
  
  describe "caller moves from initial to connected" do
    before(:each) do
      @script = Factory(:script)
      @campaign =  Factory(:preview, script: @script)    
      @callers_campaign =  Factory(:preview, script: @script)    
      @caller = Factory(:caller, campaign: @callers_campaign)
    end
    
    it "set state to caller connected" do
      caller_session = Factory(:webui_caller_session, caller: @caller, on_call: true, available_for_call: true, campaign: @campaign)
      caller_session.should_receive(:account_not_activated?).and_return(false)
      caller_session.should_receive(:subscription_limit_exceeded?).and_return(false)
      caller_session.should_receive(:time_period_exceeded?).and_return(false)
      caller_session.should_receive(:is_on_call?).and_return(false)
      # caller_session.should_receive(:disconnected?).and_return(false)      
      caller_session.should_receive(:caller_reassigned_to_another_campaign?).and_return(false)            
      caller_session.start_conf!
      caller_session.state.should eq("connected")          
    end
    
    it "shouild render correct twiml" do
      caller_session = Factory(:webui_caller_session, caller: @caller, on_call: true, available_for_call: true, campaign: @campaign)
      caller_session.should_receive(:account_not_activated?).and_return(false)
      caller_session.should_receive(:subscription_limit_exceeded?).and_return(false)
      caller_session.should_receive(:time_period_exceeded?).and_return(false)
      caller_session.should_receive(:is_on_call?).and_return(false)
      # caller_session.should_receive(:disconnected?).and_return(false)      
      caller_session.should_receive(:caller_reassigned_to_another_campaign?).and_return(false)            
      caller_session.start_conf!
      caller_session.render.should eq("<?xml version=\"1.0\" encoding=\"UTF-8\"?><Response><Dial hangupOnStar=\"true\" action=\"https://3ngz.localtunnel.com:3000/caller/#{@caller.id}/flow?event=pause_conf&amp;session_id=#{caller_session.id}\"><Conference startConferenceOnEnter=\"false\" endConferenceOnExit=\"true\" beep=\"true\" waitUrl=\"https://3ngz.localtunnel.com:3000/hold_call?version=2012-02-16+10%3A20%3A07+%2B0530\" waitMethod=\"GET\"></Conference></Dial></Response>")          
    end
    
  end
  
  describe "in connected state" do
    before(:each) do
      @script = Factory(:script)
      @campaign =  Factory(:preview, script: @script)    
      @caller = Factory(:caller, campaign: @campaign)
    end
    
    it "caller moves to disconnected state" do
      caller_session = Factory(:webui_caller_session, caller: @caller, on_call: false, available_for_call: false, campaign: @campaign, state: "connected")
      caller_session.pause_conf!
      caller_session.state.should eq("disconnected")          
    end
    
    it "render hangup twiml for disconnected state" do
      caller_session = Factory(:webui_caller_session, caller: @caller, on_call: false, available_for_call: false, campaign: @campaign, state: "connected")
      caller_session.pause_conf!
      caller_session.render.should eq("<?xml version=\"1.0\" encoding=\"UTF-8\"?><Response><Hangup/></Response>")          
    end
    
    it "should move to paused state if call not wrapped up" do
      caller_session = Factory(:webui_caller_session, caller: @caller, on_call: true, available_for_call: true, campaign: @campaign, state: "connected", voter_in_progress: Factory(:voter))
      caller_session.pause_conf!
      caller_session.state.should eq("paused")                
    end
    
    it "when paused should render right twiml" do
      caller_session = Factory(:webui_caller_session, caller: @caller, on_call: true, available_for_call: true, campaign: @campaign, state: "connected", voter_in_progress: Factory(:voter))
      caller_session.pause_conf!
      caller_session.render.should eq("<?xml version=\"1.0\" encoding=\"UTF-8\"?><Response><Say>Please enter your call results</Say><Pause length=\"11\"/><Redirect>https://3ngz.localtunnel.com:3000/caller/#{@caller.id}/flow?event=pause_conf&amp;session_id=#{caller_session.id}</Redirect></Response>")                
    end
    
    it "should move from connected back to connected if caller is ready" do
      caller_session = Factory(:webui_caller_session, caller: @caller, on_call: true, available_for_call: true, campaign: @campaign, state: "connected", voter_in_progress: nil)
      caller_session.pause_conf!
      caller_session.state.should eq("connected")                      
    end
    
    it "should render correct twiml if caller is ready" do
      caller_session = Factory(:webui_caller_session, caller: @caller, on_call: true, available_for_call: true, campaign: @campaign, state: "connected", voter_in_progress: nil)
      caller_session.pause_conf!
      caller_session.render.should eq("<?xml version=\"1.0\" encoding=\"UTF-8\"?><Response><Dial hangupOnStar=\"true\" action=\"https://3ngz.localtunnel.com:3000/caller/#{@caller.id}/flow?event=pause_conf&amp;session_id=#{caller_session.id}\"><Conference startConferenceOnEnter=\"false\" endConferenceOnExit=\"true\" beep=\"true\" waitUrl=\"https://3ngz.localtunnel.com:3000/hold_call?version=2012-02-16+10%3A20%3A07+%2B0530\" waitMethod=\"GET\"></Conference></Dial></Response>")                      
    end
        
  end
  
  
      
end