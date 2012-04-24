require "spec_helper"


describe Robo do
  
  describe "dialing" do
     it "dials its voter list" do
       campaign = Factory(:robo)
       lists = 2.times.map { Factory(:voter_list, :campaign => campaign).tap { |list| list.should_receive(:dial) } }
       campaign.stub!(:voter_lists).and_return(lists)
       campaign.dial
     end
   
     it "dials only enabled voter lists" do
       campaign = Factory(:robo)
       voter_list1 = Factory(:voter_list, :campaign => campaign)
       voter_list2 = Factory(:voter_list, :campaign => campaign, :enabled => false)
       voter_list1.should_receive(:dial)
       voter_list2.should_not_receive(:dial)
       campaign.stub!(:voter_lists).and_return([voter_list1, voter_list2])
       campaign.dial
     end
   
     it "sets the calls in progress flag when it starts dialing" do
       Campaign.send(:define_method, :dial_voters) do
         self.calls_in_progress?.should == true
       end
       campaign = Factory(:robo)
       campaign.dial
       campaign.calls_in_progress.should == false
     end
   
     it "does not start the dialer daemon for the campaign if the use has not already paid" do
       campaign = Factory(:robo, :account => Factory(:account, :activated => false))
       campaign.start(Factory(:user)).should be_false
     end
   
     it "does not start the dialer daemon for the campaign if it is already started" do
       campaign = Factory(:robo, :calls_in_progress => true)
       campaign.start(Factory(:user)).should be_false
     end
   
     it "starts the dialer daemon for the campaign if there are recordings to play" do
       script = Factory(:script)
       script.robo_recordings = [Factory(:robo_recording)]
       campaign = Factory(:robo, :script => script, :account => Factory(:account, :activated => true))
       Delayed::Job.should_receive(:enqueue)
       campaign.start(Factory(:user)).should be_true
       campaign.calls_in_progress.should be_true
     end
   
     it "does not start the dialer daemon for the campaign if its script has nothing to play" do
       script = Factory(:script)
       script.robo_recordings.size.should == 0
       campaign = Factory(:robo, :script => script, :account => Factory(:account, :activated => true))
       campaign.start(Factory(:user)).should be_false
     end
   
   
     it "stops the dialer daemon " do
       campaign = Factory(:robo, :calls_in_progress => true)
       campaign.stop
       campaign.calls_in_progress.should be_false
     end
  end
  
  describe "voicemails" do
    it "are left when a voicemail script is present" do
      campaign = Factory(:robo,  :voicemail_script => Factory(:script, :robo => true, :for_voicemail => true), :type =>Campaign::Type::PREVIEW)
      campaign.leave_voicemail?.should be_true
    end
  
    it "are not left when a voicemail script is absent" do
      campaign = Factory(:robo)
      campaign.leave_voicemail?.should be_false
    end
  end
  
  describe "answer results" do
    let(:script) { Factory(:script)}
    let(:campaign) { Factory(:robo, :script => script) }
    let(:call_attempt1) { Factory(:call_attempt,:campaign => campaign) }
    let(:call_attempt2) { Factory(:call_attempt,:campaign => campaign) }
    let(:call_attempt3) { Factory(:call_attempt,:campaign => campaign) }
    let(:call_attempt4) { Factory(:call_attempt,:campaign => campaign) }

    let(:voter1) { Factory(:voter, :campaign => campaign, :last_call_attempt => call_attempt1)}
    let(:voter2) { Factory(:voter, :campaign => campaign, :last_call_attempt => call_attempt2)}
    let(:voter3) { Factory(:voter, :campaign => campaign, :last_call_attempt => call_attempt3)}
    let(:voter4) { Factory(:voter, :campaign => campaign, :last_call_attempt => call_attempt4)}
    
    it "should give the final results of a campaign as a Hash" do
      now = Time.now
      campaign2 = Factory(:robo)
      robo_recording1 = Factory(:robo_recording, :name => "hw are u", :script => script)
      robo_recording2 = Factory(:robo_recording, :name => "wr r u", :script => script)
      recording_response1 = Factory(:recording_response, :response => "fine", :robo_recording => robo_recording1,:keypad => 1)
      recording_response2 = Factory(:recording_response, :response => "super", :robo_recording => robo_recording1,:keypad => 2)
      recording_response3 = Factory(:recording_response, :response => "[No response]", :robo_recording => robo_recording1,:keypad => 3)
  
      call_attempt1.update_attributes(:voter => voter1)
      call_attempt2.update_attributes(:voter => voter2)
      call_attempt3.update_attributes(:voter => voter3)
      call_attempt4.update_attributes(:voter => voter4)
  
      Factory(:call_response, :call_attempt => call_attempt1, campaign: campaign, :recording_response => recording_response1, :robo_recording => robo_recording1, :created_at => now)
      Factory(:call_response, :call_attempt => call_attempt2, campaign: campaign,:recording_response => recording_response2, :robo_recording => robo_recording1, :created_at => now)
      Factory(:call_response, :call_attempt => call_attempt3, campaign: campaign,:recording_response => recording_response3, :robo_recording => robo_recording1, :created_at => now)
      Factory(:call_response, :call_attempt => call_attempt4, campaign: campaign2, :recording_response => recording_response2, :robo_recording => robo_recording2, :created_at => now)
      campaign.answer_results(now, now).should == {"hw are u" => [{answer: recording_response1.response, number: 1, percentage: 33}, {answer: recording_response2.response, number: 1, percentage: 33}, {answer: recording_response3.response, number: 1, percentage: 33}], "wr r u" => [{answer: "[No response]", number: 0, percentage: 0}]}
    end
    
  end
  

end