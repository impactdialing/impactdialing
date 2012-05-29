require "spec_helper"

describe CallerCampaignReportStrategy do
  
  describe "csv header" do
    
    before (:each) do      
      @script = Factory(:script)
      @campaign = Factory(:campaign, script: @script)
      @csv = CSV.generate {}
      @selected_voter_fields = ["CustomID", "FirstName", "MiddleName"]
      @selected_custom_voter_fields = ["VAN", "Designation"]
    end
    
     it "should create csv headers" do
       strategy = CallerCampaignReportStrategy.new(@campaign, @csv, true, CampaignReportStrategy::Mode::PER_LEAD, @selected_voter_fields, @selected_custom_voter_fields)
       strategy.csv_header.should eq(["CustomID", "FirstName", "MiddleName", "VAN", "Designation", "Caller", "Status", "Call start", "Call end", "Attempts", "Recording"])       
     end
     
     it "should create csv headers and not have Attempts if per dial" do
       strategy = CallerCampaignReportStrategy.new(@campaign, @csv, true, CampaignReportStrategy::Mode::PER_DIAL, @selected_voter_fields, @selected_custom_voter_fields)
       strategy.csv_header.should eq(["CustomID", "FirstName", "MiddleName", "VAN", "Designation", "Caller", "Status", "Call start", "Call end", "Recording"])       
     end
     
     it "should create csv headers with question texts" do
       question1 = Factory(:question, text: "Q1", script: @script)
       question2 = Factory(:question, text: "Q12", script: @script)   
       answer1 = Factory(:answer, campaign: @campaign, question: question1 , voter: Factory(:voter), possible_response: Factory(:possible_response))
       answer2 = Factory(:answer, campaign: @campaign, question: question2, voter: Factory(:voter), possible_response: Factory(:possible_response))           
       strategy = CallerCampaignReportStrategy.new(@campaign, @csv, true, CampaignReportStrategy::Mode::PER_DIAL, @selected_voter_fields, @selected_custom_voter_fields)
       strategy.csv_header.should eq(["CustomID", "FirstName", "MiddleName", "VAN", "Designation", "Caller", "Status", "Call start", "Call end", "Recording", "Q1", "Q12"])       
     end
     
     it "should create csv headers with notes " do
       note1 = Factory(:note, script: @script, note:"note1")
       note2 = Factory(:note, script: @script, note:"note2")
       note_response1 = Factory(:note_response, campaign: @campaign, note: note1 , voter: Factory(:voter))
       note_response2 = Factory(:note_response, campaign: @campaign, note: note2, voter: Factory(:voter))
       strategy = CallerCampaignReportStrategy.new(@campaign, @csv, true, CampaignReportStrategy::Mode::PER_DIAL, @selected_voter_fields, @selected_custom_voter_fields)
       strategy.csv_header.should eq(["CustomID", "FirstName", "MiddleName", "VAN", "Designation", "Caller", "Status", "Call start", "Call end", "Recording", "note1", "note2"])       
     end
     
     it "should create csv headers with questions and  notes " do
       question1 = Factory(:question, text: "Q1", script: @script)
       question2 = Factory(:question, text: "Q12", script: @script)   
       answer1 = Factory(:answer, campaign: @campaign, question: question1 , voter: Factory(:voter), possible_response: Factory(:possible_response))
       answer2 = Factory(:answer, campaign: @campaign, question: question2, voter: Factory(:voter), possible_response: Factory(:possible_response))           
       
       note1 = Factory(:note, script: @script, note:"note1")
       note2 = Factory(:note, script: @script, note:"note2")
       note_response1 = Factory(:note_response, campaign: @campaign, note: note1 , voter: Factory(:voter))
       note_response2 = Factory(:note_response, campaign: @campaign, note: note2, voter: Factory(:voter))
       strategy = CallerCampaignReportStrategy.new(@campaign, @csv, true, CampaignReportStrategy::Mode::PER_DIAL, @selected_voter_fields, @selected_custom_voter_fields)
       strategy.csv_header.should eq(["CustomID", "FirstName", "MiddleName", "VAN", "Designation", "Caller", "Status", "Call start", "Call end", "Recording", "Q1", "Q12", "note1", "note2"])       
     end
     
     
     
  end
  
end
