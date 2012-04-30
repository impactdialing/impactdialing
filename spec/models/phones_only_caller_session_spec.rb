require "spec_helper"

describe PhonesOnlyCallerSession do
  
  describe "initial" do
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
        caller_session.render.should eq("<?xml version=\"1.0\" encoding=\"UTF-8\"?><Response><Gather numDigits=\"1\" timeout=\"10\" action=\"https://3ngz.localtunnel.com:3000/caller/#{@caller.id}/flow?event=read_instruction_options&amp;session=#{caller_session.id}\" method=\"POST\" finishOnKey=\"5\"><Say>Press star to begin dialing or pound for instructions.</Say></Gather></Response>")
      end    
    end
    
  end
  
  describe "read_choice" do
    
    describe "readinstruction to instructions_options  if # selected" do
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
          
    end
    
    describe "readinstruction to read_choice  if wrong option selected" do
      before(:each) do
        @script = Factory(:script)
        @campaign =  Factory(:preview, script: @script)    
        @callers_campaign =  Factory(:preview, script: @script)    
        @caller = Factory(:caller, campaign: @callers_campaign)
      end
      
      it "should go back to read_choice if wrong option selected" do
        caller_session = Factory(:phones_only_caller_session, caller: @caller, on_call: true, available_for_call: true, campaign: @campaign, digit: "x", state: "read_choice")
        caller_session.read_instruction_options!
        caller_session.state.should eq('read_choice')
      end

      it "should render twiml if wrong option selected" do
        caller_session = Factory(:phones_only_caller_session, caller: @caller, on_call: true, available_for_call: true, campaign: @campaign, digit: "x", state: "read_choice")
        caller_session.read_instruction_options!
        caller_session.render.should eq("<?xml version=\"1.0\" encoding=\"UTF-8\"?><Response><Gather numDigits=\"1\" timeout=\"10\" action=\"https://3ngz.localtunnel.com:3000/caller/#{@caller.id}/flow?event=read_instruction_options&amp;session=#{caller_session.id}\" method=\"POST\" finishOnKey=\"5\"><Say>Press star to begin dialing or pound for instructions.</Say></Gather></Response>")
      end
      
      it "should set caller state to read choice" do
        caller_session = Factory(:phones_only_caller_session, caller: @caller, on_call: true, available_for_call: true, campaign: @campaign, state: "instructions_options")
        caller_session.callin_choice!
        caller_session.state.should eq('read_choice')
      end              
    end
    
    describe "readinstruction to ready to call if * selected" do
      before(:each) do
        @script = Factory(:script)
        @campaign =  Factory(:preview, script: @script)    
        @callers_campaign =  Factory(:preview, script: @script)    
        @caller = Factory(:caller, campaign: @campaign)
      end

      it "should set caller state ready to dial" do
        caller_session = Factory(:phones_only_caller_session, caller: @caller, on_call: true, available_for_call: true, campaign: @campaign, state: "read_choice", digit: "*")
        caller_session.read_instruction_options!
        caller_session.state.should eq('ready_to_call')
      end        

      it "should render correct twiml" do
        caller_session = Factory(:phones_only_caller_session, caller: @caller, on_call: true, available_for_call: true, campaign: @campaign, state: "read_choice", digit: "*")
        caller_session.read_instruction_options!
        caller_session.render.should eq("<?xml version=\"1.0\" encoding=\"UTF-8\"?><Response><Redirect>https://3ngz.localtunnel.com:3000/caller/#{@caller.id}/flow?event=start_conf&amp;session=#{caller_session.id}</Redirect></Response>")
      end        

    end
    
    
  end
  
  describe "ready_to_call" do
    
    
    describe "time period exceeded" do
      before(:each) do
        @script = Factory(:script)
        @campaign =  Factory(:preview, script: @script,:start_time => Time.new(2011, 1, 1, 9, 0, 0), :end_time => Time.new(2011, 1, 1, 21, 0, 0), :time_zone =>"Pacific Time (US & Canada)")    
        @callers_campaign =  Factory(:preview, script: @script)    
        @caller = Factory(:caller, campaign: @callers_campaign)
      end

      it "should set caller state to time_period_exceeded" do
        caller_session = Factory(:phones_only_caller_session, caller: @caller, on_call: true, available_for_call: true, campaign: @campaign, state: "ready_to_call")
        caller_session.should_receive(:time_period_exceeded?).and_return(true)
        caller_session.start_conf!
        caller_session.state.should eq('time_period_exceeded')
      end        

      it "should render correct twiml" do
        caller_session = Factory(:phones_only_caller_session, caller: @caller, on_call: true, available_for_call: true, campaign: @campaign, state: "ready_to_call")
        caller_session.should_receive(:time_period_exceeded?).and_return(true)
        caller_session.start_conf!
        caller_session.render.should eq("<?xml version=\"1.0\" encoding=\"UTF-8\"?><Response><Say>You can only call this campaign between 9 AM and 9 PM. Please try back during those hours.</Say><Hangup/></Response>")
      end        

    end
    
    describe "caller reassigned to campaign" do
      before(:each) do
        @script = Factory(:script)
        @campaign =  Factory(:progressive, script: @script)    
        @caller = Factory(:caller, campaign: @campaign)
      end

      it "should set caller state to reassigned to campaign" do
        caller_session = Factory(:phones_only_caller_session, caller: @caller, on_call: true, available_for_call: true, campaign: @campaign, state: "ready_to_call")
        caller_session.should_receive(:caller_reassigned_to_another_campaign?).and_return(true)
        caller_session.start_conf!
        caller_session.state.should eq('reassigned_campaign')
      end        

      it "should render twiml for reassigned campaign when voters present" do
        caller_session = Factory(:phones_only_caller_session, caller: @caller, on_call: true, available_for_call: true, campaign: @campaign, state: "ready_to_call")
        caller_session.should_receive(:caller_reassigned_to_another_campaign?).and_return(true)
        caller_session.start_conf!
        caller_session.render.should eq("<?xml version=\"1.0\" encoding=\"UTF-8\"?><Response><Say>You have been re-assigned to a campaign.</Say><Redirect>https://3ngz.localtunnel.com:3000/caller/#{@caller.id}/flow?Digits=%2A&amp;event=callin_choice&amp;session=#{caller_session.id}</Redirect></Response>")
      end        

    end
    
    describe "choose voter for preview" do
      before(:each) do
        @script = Factory(:script)
        @campaign =  Factory(:preview, script: @script)    
        @callers_campaign =  Factory(:preview, script: @script)    
        @caller = Factory(:caller, campaign: @campaign)
        @voter = Factory(:voter, campaign: @campaign)
      end

      it "should set caller state to choosing_voter_to_dial" do
        caller_session = Factory(:phones_only_caller_session, caller: @caller, on_call: true, available_for_call: true, campaign: @campaign, state: "ready_to_call")
        caller_session.should_receive(:caller_reassigned_to_another_campaign?).and_return(false)
        caller_session.start_conf!
        caller_session.state.should eq('choosing_voter_to_dial')
      end     
      
      it "should set voter in progress for session" do
        caller_session = Factory(:phones_only_caller_session, caller: @caller, on_call: true, available_for_call: true, campaign: @campaign, state: "ready_to_call")
        caller_session.should_receive(:caller_reassigned_to_another_campaign?).and_return(false)
        caller_session.start_conf!
        caller_session.voter_in_progress.should eq(@voter)        
      end

      it "should render twiml for preview when voters present" do
        caller_session = Factory(:phones_only_caller_session, caller: @caller, on_call: true, available_for_call: true, campaign: @campaign, state: "ready_to_call")
        voter = Factory(:voter, FirstName:"first", LastName:"last")
        caller_session.should_receive(:caller_reassigned_to_another_campaign?).and_return(false)
        @campaign.should_receive(:next_voter_in_dial_queue).and_return(voter)
        caller_session.start_conf!
        caller_session.render.should eq("<?xml version=\"1.0\" encoding=\"UTF-8\"?><Response><Gather numDigits=\"1\" timeout=\"10\" action=\"https://3ngz.localtunnel.com:3000/caller/#{@caller.id}/flow?event=gather_response&amp;session=#{caller_session.id}&amp;voter=#{voter.id}\" method=\"POST\" finishOnKey=\"5\"><Say>first  last. Press star to dial or pound to skip.</Say></Gather></Response>")
      end        

      it "should render twiml for preview when no voters present" do
        caller_session = Factory(:phones_only_caller_session, caller: @caller, on_call: true, available_for_call: true, campaign: @campaign, state: "ready_to_call")
        caller_session.should_receive(:caller_reassigned_to_another_campaign?).and_return(false)
        @campaign.should_receive(:next_voter_in_dial_queue).and_return(nil)
        caller_session.start_conf!
        caller_session.render.should eq("<?xml version=\"1.0\" encoding=\"UTF-8\"?><Response><Say>There are no more numbers to call in this campaign.</Say></Response>")
      end        
    end
    
    describe "choose voter for power" do
      before(:each) do
        @script = Factory(:script)
        @campaign =  Factory(:progressive, script: @script)    
        @caller = Factory(:caller, campaign: @campaign)
        @voter = Factory(:voter, campaign: @campaign)
      end

      it "should set caller state to choosing_voter_and_dial" do
        caller_session = Factory(:phones_only_caller_session, caller: @caller, on_call: true, available_for_call: true, campaign: @campaign, state: "ready_to_call")
        caller_session.start_conf!
        caller_session.state.should eq('choosing_voter_and_dial')
      end        
      
      it "should set voter in progress" do
        caller_session = Factory(:phones_only_caller_session, caller: @caller, on_call: true, available_for_call: true, campaign: @campaign, state: "ready_to_call")
        caller_session.start_conf!
        caller_session.voter_in_progress.should eq(@voter)
      end        
      

      it "should render twiml for power when voters present" do
        caller_session = Factory(:phones_only_caller_session, caller: @caller, on_call: true, available_for_call: true, campaign: @campaign, state: "ready_to_call")
        voter = Factory(:voter, FirstName:"first", LastName:"last")
        @campaign.should_receive(:next_voter_in_dial_queue).and_return(voter)
        caller_session.start_conf!
        caller_session.render.should eq("<?xml version=\"1.0\" encoding=\"UTF-8\"?><Response><Say>first  last.</Say><Redirect method=\"POST\">https://3ngz.localtunnel.com:3000/caller/#{@caller.id}/flow?session_id=#{caller_session.id}&amp;voter_id=#{voter.id}</Redirect></Response>")
      end        

      it "should render twiml for power when no voters present" do
        caller_session = Factory(:phones_only_caller_session, caller: @caller, on_call: true, available_for_call: true, campaign: @campaign, state: "ready_to_call")
        @campaign.should_receive(:next_voter_in_dial_queue).and_return(nil)
        caller_session.start_conf!
        caller_session.render.should eq("<?xml version=\"1.0\" encoding=\"UTF-8\"?><Response><Say>There are no more numbers to call in this campaign.</Say></Response>")
      end        
    end    
    
    describe "start conference for predictive" do
      before(:each) do
        @script = Factory(:script)
        @campaign =  Factory(:predictive, script: @script)    
        @caller = Factory(:caller, campaign: @campaign)
      end

      it "should set caller state to conference_started_phones_only" do
        caller_session = Factory(:phones_only_caller_session, caller: @caller, on_call: true, available_for_call: true, campaign: @campaign, state: "ready_to_call")
        caller_session.should_receive(:predictive?).and_return(true)
        caller_session.should_receive(:preview_dial)
        caller_session.start_conf!
        caller_session.state.should eq('conference_started_phones_only')
      end   
      
      it "should set on_call to true" do
        caller_session = Factory(:phones_only_caller_session, caller: @caller, on_call: true, available_for_call: true, campaign: @campaign, state: "ready_to_call")
        caller_session.should_receive(:predictive?).and_return(true)
        caller_session.should_receive(:preview_dial)
        caller_session.start_conf!
        caller_session.on_call.should be_true        
      end
      
      it "should set available_for_call to true" do
        caller_session = Factory(:phones_only_caller_session, caller: @caller, on_call: true, available_for_call: true, campaign: @campaign, state: "ready_to_call")
        caller_session.should_receive(:predictive?).and_return(true)
        caller_session.should_receive(:preview_dial)
        caller_session.start_conf!
        caller_session.available_for_call.should be_true        
      end
      
      it "should set attempt_in_progress to nil" do
        caller_session = Factory(:phones_only_caller_session, caller: @caller, on_call: true, available_for_call: true, campaign: @campaign, state: "ready_to_call")
        caller_session.should_receive(:predictive?).and_return(true)
        caller_session.should_receive(:preview_dial)
        caller_session.start_conf!
        caller_session.attempt_in_progress.should be_nil        
      end
      

      it "render correct twiml" do
        caller_session = Factory(:phones_only_caller_session, caller: @caller, on_call: true, available_for_call: true, campaign: @campaign, state: "ready_to_call")
        caller_session.should_receive(:predictive?).and_return(true)
        caller_session.should_receive(:preview_dial)
        caller_session.start_conf!
        caller_session.render.should eq("<?xml version=\"1.0\" encoding=\"UTF-8\"?><Response><Dial hangupOnStar=\"true\" action=\"https://3ngz.localtunnel.com:3000/caller/#{@caller.id}/flow?event=gather_response&amp;session_id=#{caller_session.id}\"><Conference startConferenceOnEnter=\"false\" endConferenceOnExit=\"true\" beep=\"true\" waitUrl=\"https://3ngz.localtunnel.com:3000/hold_call?version=2012-02-16+10%3A20%3A07+%2B0530\" waitMethod=\"GET\"></Conference></Dial></Response>")
      end        
    end
  end
  
  describe "choosing_voter_to_dial" do
    before(:each) do
      @script = Factory(:script)
      @campaign =  Factory(:preview, script: @script)    
      @caller = Factory(:caller, campaign: @campaign)
    end
    
    describe "skip voter if # selected" do
      it "should set caller state to skipped voter if pound selected" do
        voter = Factory(:voter, FirstName:"first", LastName:"last")
        caller_session = Factory(:phones_only_caller_session, caller: @caller, on_call: true, available_for_call: true, campaign: @campaign, state: "choosing_voter_to_dial", digit: "#", voter_in_progress: voter)
        voter.should_receive(:skip)
        caller_session.start_conf!
        caller_session.state.should eq('skip_voter')
      end      
      
      it "should render correct twiml if pound selected" do
        voter = Factory(:voter, FirstName:"first", LastName:"last")
        caller_session = Factory(:phones_only_caller_session, caller: @caller, on_call: true, available_for_call: true, campaign: @campaign, state: "choosing_voter_to_dial", digit: "#", voter_in_progress: voter)
        voter.should_receive(:skip)
        caller_session.start_conf!
        caller_session.render.should eq("<?xml version=\"1.0\" encoding=\"UTF-8\"?><Response><Redirect>https://3ngz.localtunnel.com:3000/caller/#{@caller.id}/flow?event=skipped_voter&amp;session=#{caller_session.id}</Redirect></Response>")
      end        
      
    end
    
    describe "start conference for preview if * selected" do
      before(:each) do
        @script = Factory(:script)
        @campaign =  Factory(:preview, script: @script)    
        @caller = Factory(:caller, campaign: @campaign)
      end
      

      it "should set caller state to conference_started_phones_only" do
        caller_session = Factory(:phones_only_caller_session, caller: @caller, on_call: true, available_for_call: true, campaign: @campaign, state: "choosing_voter_to_dial", digit: "*")
        caller_session.should_receive(:preview_dial)
        caller_session.start_conf!
        caller_session.state.should eq('conference_started_phones_only')
      end        

      it "render correct twiml" do
        caller_session = Factory(:phones_only_caller_session, caller: @caller, on_call: true, available_for_call: true, campaign: @campaign, state: "choosing_voter_and_dial", digit: "*")
        caller_session.should_receive(:preview_dial)
        caller_session.start_conf!
        caller_session.render.should eq("<?xml version=\"1.0\" encoding=\"UTF-8\"?><Response><Dial hangupOnStar=\"true\" action=\"https://3ngz.localtunnel.com:3000/caller/#{@caller.id}/flow?event=gather_response&amp;session_id=#{caller_session.id}\"><Conference startConferenceOnEnter=\"false\" endConferenceOnExit=\"true\" beep=\"true\" waitUrl=\"https://3ngz.localtunnel.com:3000/hold_call?version=2012-02-16+10%3A20%3A07+%2B0530\" waitMethod=\"GET\"></Conference></Dial></Response>")
      end        
    end
    
    describe "read_to_call for preview if wrong option selected" do
      before(:each) do
        @script = Factory(:script)
        @campaign =  Factory(:preview, script: @script)    
        @caller = Factory(:caller, campaign: @campaign)
      end
      
      it "should set caller state to ready_to_call" do
        caller_session = Factory(:phones_only_caller_session, caller: @caller, on_call: true, available_for_call: true, campaign: @campaign, state: "choosing_voter_to_dial", digit: "+")
        caller_session.start_conf!
        caller_session.state.should eq('ready_to_call')
      end        
      
      it "should set caller state to ready_to_call if nothing selected" do
        caller_session = Factory(:phones_only_caller_session, caller: @caller, on_call: true, available_for_call: true, campaign: @campaign, state: "choosing_voter_to_dial")
        caller_session.start_conf!
        caller_session.state.should eq('ready_to_call')
      end        
      
      
      
      
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
      caller_session.should_receive(:preview_dial)
      caller_session.start_conf!
      caller_session.state.should eq('conference_started_phones_only')
    end        
    
    it "render correct twiml" do
      caller_session = Factory(:phones_only_caller_session, caller: @caller, on_call: true, available_for_call: true, campaign: @campaign, state: "choosing_voter_and_dial", digit: "*")
      caller_session.should_receive(:preview_dial)
      caller_session.start_conf!
      caller_session.render.should eq("<?xml version=\"1.0\" encoding=\"UTF-8\"?><Response><Dial hangupOnStar=\"true\" action=\"https://3ngz.localtunnel.com:3000/caller/#{@caller.id}/flow?event=gather_response&amp;session_id=#{caller_session.id}\"><Conference startConferenceOnEnter=\"false\" endConferenceOnExit=\"true\" beep=\"true\" waitUrl=\"https://3ngz.localtunnel.com:3000/hold_call?version=2012-02-16+10%3A20%3A07+%2B0530\" waitMethod=\"GET\"></Conference></Dial></Response>")
    end        
  end
  
  
  
  
  
end    
