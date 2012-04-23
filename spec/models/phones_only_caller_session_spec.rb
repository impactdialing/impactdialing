require "spec_helper"

describe PhonesOnlyCallerSession do
  
  describe "callin_choice " do
    before(:each) do
      @script = Factory(:script)
      @campaign =  Factory(:preview, script: @script)    
      @callers_campaign =  Factory(:preview, script: @script)    
      @caller = Factory(:caller, campaign: @callers_campaign)
    end
    
    
    it "should set caller state to read choice" do
      caller_session = Factory(:phones_only_caller_session, caller: @caller, on_call: true, available_for_call: true, campaign: @campaign)
      caller_session.callin_choice!
      caller_session.state.should eq('read_choice')
    end
    
    it "should render correct twiml" do
      caller_session = Factory(:phones_only_caller_session, caller: @caller, on_call: true, available_for_call: true, campaign: @campaign)
      caller_session.callin_choice!
      caller_session.render.should eq("<?xml version=\"1.0\" encoding=\"UTF-8\"?><Response><gather numDigits=\"1\" timeout=\"10\" action=\"https://3ngz.localtunnel.com:3000/caller/#{@caller.id}/flow?event=read_instruction_options&amp;session=#{caller_session.id}\" method=\"POST\" finishOnKey=\"5\"><say>Press star to begin dialing or pound for instructions.</say></gather></Response>")
    end    
  end
  
  describe "read instructions" do
    before(:each) do
      @script = Factory(:script)
      @campaign =  Factory(:preview, script: @script)    
      @callers_campaign =  Factory(:preview, script: @script)    
      @caller = Factory(:caller, campaign: @callers_campaign)
    end
    
    it "should set caller state to instructions_options" do
      caller_session = Factory(:phones_only_caller_session, caller: @caller, on_call: true, available_for_call: true, campaign: @campaign, digit: "#", state: "read_choice")
      caller_session.read_instruction_options!
      caller_session.state.should eq('instructions_options')
    end
    
    it "should render correct twiml" do
      caller_session = Factory(:phones_only_caller_session, caller: @caller, on_call: true, available_for_call: true, campaign: @campaign, digit: "#", state: "read_choice")
      caller_session.read_instruction_options!
      caller_session.render.should eq("<?xml version=\"1.0\" encoding=\"UTF-8\"?><Response><Say>After these instructions, you will be placed on hold. When someone answers the phone, the hold music will stop. You usually won't hear the person say hello, so start talking immediately. At the end of the conversation, do not hang up your phone. Instead, press star to end the call, and you will be given instructions on how to enter your call results. Press star to begin dialing or pound for instructions.</Say><Redirect>https://3ngz.localtunnel.com:3000/caller/#{@caller.id}/flow?event=callin_choice&amp;session=#{caller_session.id}</Redirect></Response>")
    end
    
    it "should go back to read_choice if wrong option selected" do
      caller_session = Factory(:phones_only_caller_session, caller: @caller, on_call: true, available_for_call: true, campaign: @campaign, digit: "x", state: "read_choice")
      caller_session.read_instruction_options!
      caller_session.state.should eq('read_choice')
    end
    
    it "should render twiml if wrong option selected" do
      caller_session = Factory(:phones_only_caller_session, caller: @caller, on_call: true, available_for_call: true, campaign: @campaign, digit: "x", state: "read_choice")
      caller_session.read_instruction_options!
      caller_session.render.should eq("<?xml version=\"1.0\" encoding=\"UTF-8\"?><Response><gather numDigits=\"1\" timeout=\"10\" action=\"https://3ngz.localtunnel.com:3000/caller/#{@caller.id}/flow?event=read_instruction_options&amp;session=#{caller_session.id}\" method=\"POST\" finishOnKey=\"5\"><say>Press star to begin dialing or pound for instructions.</say></gather></Response>")
    end
    
    it "should set caller state to read choice" do
      caller_session = Factory(:phones_only_caller_session, caller: @caller, on_call: true, available_for_call: true, campaign: @campaign, state: "instructions_options")
      caller_session.callin_choice!
      caller_session.state.should eq('read_choice')
    end        
  end
  
  describe "time period exceeded" do
    before(:each) do
      @script = Factory(:script)
      @campaign =  Factory(:preview, script: @script)    
      @callers_campaign =  Factory(:preview, script: @script)    
      @caller = Factory(:caller, campaign: @callers_campaign)
    end
    
    it "should set caller state to choosing_voter_to_dial" do
      caller_session = Factory(:phones_only_caller_session, caller: @caller, on_call: true, available_for_call: true, campaign: @campaign, state: "read_choice", digit: "*")
      caller_session.should_receive(:star_selected_and_time_period_exceeded?).and_return(true)
      caller_session.read_instruction_options!
      caller_session.state.should eq('time_period_exceeded')
    end        
    
    it "should render correct twiml" do
      caller_session = Factory(:phones_only_caller_session, caller: @caller, on_call: true, available_for_call: true, campaign: @campaign, state: "read_choice", digit: "*")
      caller_session.should_receive(:star_selected_and_time_period_exceeded?).and_return(true)
      caller_session.read_instruction_options!
      caller_session.render.should eq("<?xml version=\"1.0\" encoding=\"UTF-8\"?><Response><Say>You can only call this campaign between 6 PM and 5 PM. Please try back during those hours.</Say><Hangup/></Response>")
    end        
    
    
    
  end
  
  describe "choose voter for preview" do
    before(:each) do
      @script = Factory(:script)
      @campaign =  Factory(:preview, script: @script)    
      @callers_campaign =  Factory(:preview, script: @script)    
      @caller = Factory(:caller, campaign: @callers_campaign)
    end
    
    it "should set caller state to choosing_voter_to_dial" do
      caller_session = Factory(:phones_only_caller_session, caller: @caller, on_call: true, available_for_call: true, campaign: @campaign, state: "read_choice", digit: "*")
      caller_session.should_receive(:star_selected_and_caller_reassigned_to_another_campaign?).and_return(false)
      caller_session.read_instruction_options!
      caller_session.state.should eq('choosing_voter_to_dial')
    end        
    
    it "should render twiml for preview when voters present" do
      caller_session = Factory(:phones_only_caller_session, caller: @caller, on_call: true, available_for_call: true, campaign: @campaign, state: "read_choice", digit: "*")
      voter = Factory(:voter, FirstName:"first", LastName:"last")
      caller_session.should_receive(:star_selected_and_caller_reassigned_to_another_campaign?).and_return(false)
      @campaign.should_receive(:next_voter_in_dial_queue).and_return(voter)
      caller_session.read_instruction_options!
      caller_session.render.should eq("<?xml version=\"1.0\" encoding=\"UTF-8\"?><Response><gather numDigits=\"1\" timeout=\"10\" action=\"https://3ngz.localtunnel.com:3000/caller/#{@caller.id}/flow?session=#{caller_session.id}&amp;voter=#{voter.id}\" method=\"POST\" finishOnKey=\"5\"><Say>first  last. Press star to dial or pound to skip.</Say></gather></Response>")
    end        
    
    it "should render twiml for preview when no voters present" do
      caller_session = Factory(:phones_only_caller_session, caller: @caller, on_call: true, available_for_call: true, campaign: @campaign, state: "read_choice", digit: "*")
      caller_session.should_receive(:star_selected_and_caller_reassigned_to_another_campaign?).and_return(false)
      @campaign.should_receive(:next_voter_in_dial_queue).and_return(nil)
      caller_session.read_instruction_options!
      caller_session.render.should eq("<?xml version=\"1.0\" encoding=\"UTF-8\"?><Response><say>There are no more numbers to call in this campaign.</say></Response>")
    end        
  end
  
  describe "choose voter for power" do
    before(:each) do
      @script = Factory(:script)
      @campaign =  Factory(:progressive, script: @script)    
      @caller = Factory(:caller, campaign: @campaign)
    end
    
    it "should set caller state to choosing_voter_and_dial" do
      caller_session = Factory(:phones_only_caller_session, caller: @caller, on_call: true, available_for_call: true, campaign: @campaign, state: "read_choice", digit: "*")
      caller_session.read_instruction_options!
      caller_session.state.should eq('choosing_voter_and_dial')
    end        
    
    it "should render twiml for preview when voters present" do
      caller_session = Factory(:phones_only_caller_session, caller: @caller, on_call: true, available_for_call: true, campaign: @campaign, state: "read_choice", digit: "*")
      voter = Factory(:voter, FirstName:"first", LastName:"last")
      @campaign.should_receive(:next_voter_in_dial_queue).and_return(voter)
      caller_session.read_instruction_options!
      caller_session.render.should eq("<?xml version=\"1.0\" encoding=\"UTF-8\"?><Response><say>first  last.</say><Redirect method=\"POST\">https://3ngz.localtunnel.com:3000/caller/#{@caller.id}/flow?session_id=#{caller_session.id}&amp;voter_id=#{voter.id}</Redirect></Response>")
    end        
    
    it "should render twiml for preview when no voters present" do
      caller_session = Factory(:phones_only_caller_session, caller: @caller, on_call: true, available_for_call: true, campaign: @campaign, state: "read_choice", digit: "*")
      @campaign.should_receive(:next_voter_in_dial_queue).and_return(nil)
      caller_session.read_instruction_options!
      caller_session.render.should eq("<?xml version=\"1.0\" encoding=\"UTF-8\"?><Response><say>There are no more numbers to call in this campaign.</say></Response>")
    end        
  end
  
  describe "caller reassigned to campaign" do
    before(:each) do
      @script = Factory(:script)
      @campaign =  Factory(:progressive, script: @script)    
      @caller = Factory(:caller, campaign: @campaign)
    end
    
    it "should set caller state to reassigned to campaign" do
      caller_session = Factory(:phones_only_caller_session, caller: @caller, on_call: true, available_for_call: true, campaign: @campaign, state: "read_choice", digit: "*")
      caller_session.should_receive(:star_selected_and_caller_reassigned_to_another_campaign?).and_return(true)
      caller_session.read_instruction_options!
      caller_session.state.should eq('reassigned_campaign')
    end        
    
    it "should render twiml for preview when voters present" do
      caller_session = Factory(:phones_only_caller_session, caller: @caller, on_call: true, available_for_call: true, campaign: @campaign, state: "read_choice", digit: "*")
      caller_session.should_receive(:star_selected_and_caller_reassigned_to_another_campaign?).and_return(true)
      caller_session.read_instruction_options!
      caller_session.render.should eq("<?xml version=\"1.0\" encoding=\"UTF-8\"?><Response><Say>You have been re-assigned to a campaign.</Say><Redirect>https://3ngz.localtunnel.com:3000/caller/#{@caller.id}/flow?Digits=%2A&amp;event=callin_choice&amp;session=#{caller_session.id}</Redirect></Response>")
    end        
    
  end
  
  describe "start conference for predictive" do
    before(:each) do
      @script = Factory(:script)
      @campaign =  Factory(:predictive, script: @script)    
      @caller = Factory(:caller, campaign: @campaign)
    end
    
    it "should set caller state to conference_started_phones_only" do
      caller_session = Factory(:phones_only_caller_session, caller: @caller, on_call: true, available_for_call: true, campaign: @campaign, state: "read_choice", digit: "*")
      caller_session.should_receive(:star_selected_and_predictive?).and_return(true)
      caller_session.read_instruction_options!
      caller_session.state.should eq('conference_started_phones_only')
    end        
    
    it "render correct twiml" do
      caller_session = Factory(:phones_only_caller_session, caller: @caller, on_call: true, available_for_call: true, campaign: @campaign, state: "read_choice", digit: "*")
      caller_session.should_receive(:star_selected_and_predictive?).and_return(true)
      caller_session.read_instruction_options!
      caller_session.render.should eq("<?xml version=\"1.0\" encoding=\"UTF-8\"?><Response><Dial hangupOnStar=\"true\" action=\"https://3ngz.localtunnel.com:3000/caller/#{@caller.id}/flow?event=gather_response&amp;session_id=#{caller_session.id}\"><Conference startConferenceOnEnter=\"false\" endConferenceOnExit=\"true\" beep=\"true\" waitUrl=\"https://3ngz.localtunnel.com:3000/hold_call?version=2012-02-16+10%3A20%3A07+%2B0530\" waitMethod=\"GET\"></Conference></Dial></Response>")
    end        
    
    
  end
  
  describe "start conference for power" do
    before(:each) do
      @script = Factory(:script)
      @campaign =  Factory(:progressive, script: @script)    
      @caller = Factory(:caller, campaign: @campaign)
    end
    
    it "should set caller state to conference_started_phones_only" do
      caller_session = Factory(:phones_only_caller_session, caller: @caller, on_call: true, available_for_call: true, campaign: @campaign, state: "choosing_voter_and_dial", digit: "*")
      caller_session.start_conf!
      caller_session.state.should eq('conference_started_phones_only')
    end        
    
    it "render correct twiml" do
      caller_session = Factory(:phones_only_caller_session, caller: @caller, on_call: true, available_for_call: true, campaign: @campaign, state: "choosing_voter_and_dial", digit: "*")
      caller_session.start_conf!
      caller_session.render.should eq("<?xml version=\"1.0\" encoding=\"UTF-8\"?><Response><Dial hangupOnStar=\"true\" action=\"https://3ngz.localtunnel.com:3000/caller/#{@caller.id}/flow?event=gather_response&amp;session_id=#{caller_session.id}\"><Conference startConferenceOnEnter=\"false\" endConferenceOnExit=\"true\" beep=\"true\" waitUrl=\"https://3ngz.localtunnel.com:3000/hold_call?version=2012-02-16+10%3A20%3A07+%2B0530\" waitMethod=\"GET\"></Conference></Dial></Response>")
    end        
  end
  
  
  
end    
