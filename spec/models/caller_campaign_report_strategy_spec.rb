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
       strategy = CallerCampaignReportStrategy.new(@campaign, @csv, true, CampaignReportStrategy::Mode::PER_LEAD, @selected_voter_fields, @selected_custom_voter_fields, nil, nil)
       strategy.csv_header.should eq(["ID", "First name", "Middle name", "VAN", "Designation", "Caller", "Status", "Time Dialed", "Time Answered", "Time Ended", "Attempts", "Recording"])       
     end
     
     it "should create csv headers and not have Attempts if per dial" do
       strategy = CallerCampaignReportStrategy.new(@campaign, @csv, true, CampaignReportStrategy::Mode::PER_DIAL, @selected_voter_fields, @selected_custom_voter_fields, nil, nil)
       strategy.csv_header.should eq(["ID", "First name", "Middle name", "VAN", "Designation", "Caller", "Status", "Time Dialed", "Time Answered", "Time Ended", "Recording"])       
     end
     
     it "should manipulate headers" do
       selected_voter_fields = ["CustomID", "LastName", "FirstName", "MiddleName", "address", "city", "state", "zip_code", "country"]
       strategy = CallerCampaignReportStrategy.new(@campaign, @csv, true, CampaignReportStrategy::Mode::PER_LEAD, selected_voter_fields, @selected_custom_voter_fields, nil, nil)
       strategy.csv_header.should eq(["ID", "Last name", "First name", "Middle name", "Address", "City", "State", "Zip code", "Country", "VAN", "Designation", "Caller", "Status", "Time Dialed", "Time Answered", "Time Ended", "Attempts", "Recording"])              
     end
     
     it "should create csv headers with question texts" do
       question1 = Factory(:question, text: "Q1", script: @script)
       question2 = Factory(:question, text: "Q12", script: @script)   
       answer1 = Factory(:answer, campaign: @campaign, question: question1 , voter: Factory(:voter), possible_response: Factory(:possible_response))
       answer2 = Factory(:answer, campaign: @campaign, question: question2, voter: Factory(:voter), possible_response: Factory(:possible_response))           
       strategy = CallerCampaignReportStrategy.new(@campaign, @csv, true, CampaignReportStrategy::Mode::PER_DIAL, @selected_voter_fields, @selected_custom_voter_fields, nil, nil)
       strategy.csv_header.should eq(["ID", "First name", "Middle name", "VAN", "Designation", "Caller", "Status", "Time Dialed", "Time Answered", "Time Ended", "Recording", "Q1", "Q12"])       
     end
     
     it "should create csv headers with notes " do
       note1 = Factory(:note, script: @script, note:"note1")
       note2 = Factory(:note, script: @script, note:"note2")
       note_response1 = Factory(:note_response, campaign: @campaign, note: note1 , voter: Factory(:voter))
       note_response2 = Factory(:note_response, campaign: @campaign, note: note2, voter: Factory(:voter))
       strategy = CallerCampaignReportStrategy.new(@campaign, @csv, true, CampaignReportStrategy::Mode::PER_DIAL, @selected_voter_fields, @selected_custom_voter_fields, nil, nil)
       strategy.csv_header.should eq(["ID", "First name", "Middle name", "VAN", "Designation", "Caller", "Status", "Time Dialed", "Time Answered", "Time Ended", "Recording", "note1", "note2"])       
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
       strategy = CallerCampaignReportStrategy.new(@campaign, @csv, true, CampaignReportStrategy::Mode::PER_DIAL, @selected_voter_fields, @selected_custom_voter_fields, nil, nil)
       strategy.csv_header.should eq(["ID", "First name", "Middle name", "VAN", "Designation", "Caller", "Status", "Time Dialed", "Time Answered", "Time Ended", "Recording", "Q1", "Q12", "note1", "note2"])       
     end
  end
  
  describe "call_attempt_info" do
    before (:each) do      
      @script = Factory(:script)
      @campaign = Factory(:campaign, script: @script)
      @csv = CSV.generate {}
      @selected_voter_fields = ["CustomID", "FirstName", "MiddleName"]
      @selected_custom_voter_fields = ["VAN", "Designation"]
    end
    
    it "should create the basic info for per dial" do
      caller = Factory(:caller, email: "abc@hui.com")
      voter = Factory(:voter)
      call_attempt = Factory(:call_attempt, voter: voter, status: CallAttempt::Status::SUCCESS, call_start: Time.at(1338292076), connecttime: Time.at(1338292476), call_end: Time.at(1338293196), recording_url: "xyz")
      strategy = CallerCampaignReportStrategy.new(@campaign, @csv, true, CampaignReportStrategy::Mode::PER_DIAL, @selected_voter_fields, @selected_custom_voter_fields, nil, nil)
      strategy.call_attempt_info(call_attempt.attributes).should eq(["a caller", "Answered", Time.at(1338292076).in_time_zone(@campaign.time_zone), Time.at(1338292476).in_time_zone(@campaign.time_zone), Time.at(1338293196).in_time_zone(@campaign.time_zone), "xyz.mp3"])
    end
    
    it "should create the basic info for per lead" do
      caller = Factory(:caller, email: "abc@hui.com")
      voter = Factory(:voter)
      call_attempt = Factory(:call_attempt, voter: voter, status: CallAttempt::Status::SUCCESS, call_start: Time.at(1338292076), connecttime: Time.at(1338292476), call_end: Time.at(1338293196), recording_url: "xyz")
      strategy = CallerCampaignReportStrategy.new(@campaign, @csv, true, CampaignReportStrategy::Mode::PER_LEAD, @selected_voter_fields, @selected_custom_voter_fields, nil, nil)
      strategy.call_attempt_info(call_attempt.attributes).should eq(["a caller", "Answered", Time.at(1338292076).in_time_zone(@campaign.time_zone), Time.at(1338292476).in_time_zone(@campaign.time_zone), Time.at(1338293196).in_time_zone(@campaign.time_zone), 1 ,"xyz.mp3"])
    end
    
  end
  
  describe "call_attempt_details" do
    let(:voter) { Factory(:voter) }

    before (:each) do      
      @script = Factory(:script)
      @campaign = Factory(:campaign, script: @script)
      @csv = CSV.generate {}
      @selected_voter_fields = ["CustomID", "FirstName", "MiddleName"]
      @selected_custom_voter_fields = ["VAN", "Designation"]
      caller = Factory(:caller)
      question1 = Factory(:question, text: "Q1", script: @script)
      question2 = Factory(:question, text: "Q12", script: @script)   
      answer1 = Factory(:answer, campaign: @campaign, question_id: question1.id , voter: voter, possible_response: Factory(:possible_response, question_id: question1.id, value: "Hey"), call_attempt: call_attempt)
      answer2 = Factory(:answer, campaign: @campaign, question_id: question2.id, voter: voter, possible_response: Factory(:possible_response, question_id: question2.id, value: "Wee"), call_attempt: call_attempt)           
      note1 = Factory(:note, script: @script, note:"note1")
      note2 = Factory(:note, script: @script, note:"note2")
      note_response1 = Factory(:note_response, campaign: @campaign, note: note1 , voter: Factory(:voter), call_attempt: call_attempt, response: "Test2")
      note_response2 = Factory(:note_response, campaign: @campaign, note: note2, voter: Factory(:voter), call_attempt: call_attempt, response: "Test1")
      @strategy = CallerCampaignReportStrategy.new(@campaign, @csv, true, CampaignReportStrategy::Mode::PER_DIAL, @selected_voter_fields, @selected_custom_voter_fields, nil, nil)
      @answers = @strategy.get_answers([call_attempt.id])[call_attempt.id]
      @note_responses = @strategy.get_note_responses([call_attempt.id])[call_attempt.id]
    end
    
    context "success" do
      let(:call_attempt) do
        Factory(:call_attempt,
                voter: voter,
                status: CallAttempt::Status::SUCCESS,
                call_start: Time.at(1338292076),
                connecttime: Time.at(1338292476),
                call_end: Time.at(1338293196),
                recording_url: "xyz"
               )
      end

      it "should create the csv row" do
        @strategy.call_attempt_details(call_attempt.attributes, @answers, @note_responses).should eq(["a caller", "Answered", Time.at(1338292076).in_time_zone(@campaign.time_zone), Time.at(1338292476).in_time_zone(@campaign.time_zone), Time.at(1338293196).in_time_zone(@campaign.time_zone), "xyz.mp3","Hey", "Wee", "Test2", "Test1"])
      end
    end
    
    context "ringing" do
      let(:call_attempt) { Factory(:call_attempt, voter: voter, status: CallAttempt::Status::RINGING) }
      it "should create the csv row convert ringing to not dialed" do
        @strategy.call_attempt_details(call_attempt.attributes, @answers, @note_responses).should eq([nil, "Not Dialed", "", "", "", "", [], []])
      end
    end
    
    context "ready" do
      let(:call_attempt) { Factory(:call_attempt, voter: voter, status: CallAttempt::Status::READY) }
      it "should create the csv row convert ready to not dialed" do
        @strategy.call_attempt_details(call_attempt.attributes, @answers, @note_responses).should eq([nil, "Not Dialed", "", "", "", "", [], []])
      end
    end
  end
  
  describe "csv_for_call_attempt" do
    before (:each) do      
      @account = Factory(:account)
      @script = Factory(:script, account: @account)
      @campaign = Factory(:campaign, script: @script, account: @account)
      @csv = CSV.generate {}
      @selected_voter_fields = ["CustomID", "FirstName", "Phone"]
      @selected_custom_voter_fields = ["field1", "field2"]
    end
    
    it "should create the csv row when a question is deleted" do
       caller = Factory(:caller, email: "abc@hui.com")       
       voter = Factory(:voter, account: @account)     
       phone, custom_id, firstname = "39045098753", "24566", "first"
       voter.update_attributes(:Phone => phone, :CustomID => custom_id, :FirstName => firstname)        
       field1  = Factory(:custom_voter_field, :name => "field1", :account => @account)
       field2 = Factory(:custom_voter_field, :name => "field2", :account => @account)
       
       value1 = Factory(:custom_voter_field_value, :voter => voter, :custom_voter_field => field1, :value => "value1")
       value2 = Factory(:custom_voter_field_value, :voter => voter, :custom_voter_field => field2, :value => "value2")
       
       call_attempt = Factory(:call_attempt, voter: voter, status: CallAttempt::Status::SUCCESS, call_start: Time.at(1338292076), connecttime: Time.at(1338292476), call_end: Time.at(1338293196), recording_url: "xyz")
       question1 = Factory(:question, text: "Q1", script: @script)
       question2 = Factory(:question, text: "Q12", script: @script)   
       answer1 = Factory(:answer, campaign: @campaign, question_id: question1.id , voter: voter, possible_response: Factory(:possible_response, question_id: question1.id, value: "Hey"), call_attempt: call_attempt)
       answer2 = Factory(:answer, campaign: @campaign, question_id: question2.id, voter: voter, possible_response: Factory(:possible_response, question_id: question2.id, value: "Wee"), call_attempt: call_attempt)           
       answer3 = Factory(:answer, campaign: @campaign, question_id: 13456, voter: voter, possible_response: Factory(:possible_response, question_id: 13456, value: "Tree"), call_attempt: call_attempt)                  
       note1 = Factory(:note, script: @script, note:"note1")
       note2 = Factory(:note, script: @script, note:"note2")
       note_response1 = Factory(:note_response, campaign: @campaign, note: note1 , voter: Factory(:voter), call_attempt: call_attempt, response: "Test2")
       note_response2 = Factory(:note_response, campaign: @campaign, note: note2, voter: Factory(:voter), call_attempt: call_attempt, response: "Test1")
       strategy = CallerCampaignReportStrategy.new(@campaign, @csv, true, CampaignReportStrategy::Mode::PER_DIAL, 
       @selected_voter_fields, @selected_custom_voter_fields, nil, nil)
       answers = strategy.get_answers([call_attempt.id])[call_attempt.id]
       responses = strategy.get_note_responses([call_attempt.id])[call_attempt.id]
       strategy.call_attempt_details(call_attempt, answers, responses).should eq(["a caller", "Answered", Time.at(1338292076).in_time_zone(@campaign.time_zone), Time.at(1338292476).in_time_zone(@campaign.time_zone), Time.at(1338293196).in_time_zone(@campaign.time_zone), "xyz.mp3","Hey", "Wee", "Tree", "Test2", "Test1"])
     end
    
  end
  
  describe "csv_for" do
    before (:each) do      
      @account = Factory(:account)
      @script = Factory(:script, account: @account)
      @campaign = Factory(:campaign, script: @script, account: @account)
      @csv = CSV.generate {}
      @selected_voter_fields = ["CustomID", "FirstName", "Phone"]
      @selected_custom_voter_fields = ["field1", "field2"]
    end
    
    it "should create the csv row when a question is deleted" do
       caller = Factory(:caller, email: "abc@hui.com")       
       voter = Factory(:voter, account: @account)     
       phone, custom_id, firstname = "39045098753", "24566", "first"
       voter.update_attributes(:Phone => phone, :CustomID => custom_id, :FirstName => firstname)        
       field1  = Factory(:custom_voter_field, :name => "field1", :account => @account)
       field2 = Factory(:custom_voter_field, :name => "field2", :account => @account)
       
       value1 = Factory(:custom_voter_field_value, :voter => voter, :custom_voter_field => field1, :value => "value1")
       value2 = Factory(:custom_voter_field_value, :voter => voter, :custom_voter_field => field2, :value => "value2")
       
       call_attempt = Factory(:call_attempt, voter: voter, status: CallAttempt::Status::SUCCESS, call_start: Time.at(1338292076), connecttime: Time.at(1338292476), call_end: Time.at(1338293196), recording_url: "xyz")
       question1 = Factory(:question, text: "Q1", script: @script)
       question2 = Factory(:question, text: "Q12", script: @script)   
       answer1 = Factory(:answer, campaign: @campaign, question_id: question1.id , voter: voter, possible_response: Factory(:possible_response, question_id: question1.id, value: "Hey"), call_attempt: call_attempt)
       answer2 = Factory(:answer, campaign: @campaign, question_id: question2.id, voter: voter, possible_response: Factory(:possible_response, question_id: question2.id, value: "Wee"), call_attempt: call_attempt)           
       answer3 = Factory(:answer, campaign: @campaign, question_id: 13456, voter: voter, possible_response: Factory(:possible_response, question_id: 13456, value: "Tree"), call_attempt: call_attempt)                  
       note1 = Factory(:note, script: @script, note:"note1")
       note2 = Factory(:note, script: @script, note:"note2")
       note_response1 = Factory(:note_response, campaign: @campaign, note: note1 , voter: Factory(:voter), call_attempt: call_attempt, response: "Test2")
       note_response2 = Factory(:note_response, campaign: @campaign, note: note2, voter: Factory(:voter), call_attempt: call_attempt, response: "Test1")
       strategy = CallerCampaignReportStrategy.new(@campaign, @csv, true, CampaignReportStrategy::Mode::PER_DIAL, 
       @selected_voter_fields, @selected_custom_voter_fields, nil, nil)
       strategy.csv_for(voter).should eq(["24566", "first", "39045098753", "value1", "value2", [nil, "Not Dialed", "", "", "", "", [], []]])
     end
    
  end
  
  describe "construct_csv" do
     before (:each) do      
       @account = Factory(:account)
       @script = Factory(:script, account: @account)
       @campaign = Factory(:campaign, script: @script, account: @account)
       @csv = []
       @selected_voter_fields = ["CustomID", "FirstName", "Phone"]
       @selected_custom_voter_fields = ["field1", "field2"]
     end

     it "should create the csv for download all per dial" do
        caller = Factory(:caller, email: "abc@hui.com")       
        voter = Factory(:voter, account: @account, campaign: @campaign)     
        phone, custom_id, firstname = "39045098753", "24566", "first"
        voter.update_attributes(:Phone => phone, :CustomID => custom_id, :FirstName => firstname)        
        field1  = Factory(:custom_voter_field, :name => "field1", :account => @account)
        field2 = Factory(:custom_voter_field, :name => "field2", :account => @account)

        value1 = Factory(:custom_voter_field_value, :voter => voter, :custom_voter_field => field1, :value => "value1")
        value2 = Factory(:custom_voter_field_value, :voter => voter, :custom_voter_field => field2, :value => "value2")

        call_attempt = Factory(:call_attempt, voter: voter, status: CallAttempt::Status::SUCCESS, call_start: Time.at(1338292076), connecttime: Time.at(1338292476), call_end: Time.at(1338293196), recording_url: "xyz",campaign: @campaign)
        question1 = Factory(:question, text: "Q1", script: @script)
        question2 = Factory(:question, text: "Q12", script: @script)   
        answer1 = Factory(:answer, campaign: @campaign, question_id: question1.id , voter: voter, possible_response: Factory(:possible_response, question_id: question1.id, value: "Hey"), call_attempt: call_attempt)
        answer2 = Factory(:answer, campaign: @campaign, question_id: question2.id, voter: voter, possible_response: Factory(:possible_response, question_id: question2.id, value: "Wee"), call_attempt: call_attempt)           
        answer3 = Factory(:answer, campaign: @campaign, question_id: 13456, voter: voter, possible_response: Factory(:possible_response, question_id: 13456, value: "Tree"), call_attempt: call_attempt)                  
        note1 = Factory(:note, script: @script, note:"note1")
        note2 = Factory(:note, script: @script, note:"note2")
        note_response1 = Factory(:note_response, campaign: @campaign, note: note1 , voter: Factory(:voter), call_attempt: call_attempt, response: "Test2")
        note_response2 = Factory(:note_response, campaign: @campaign, note: note2, voter: Factory(:voter), call_attempt: call_attempt, response: "Test1")
        strategy = CallerCampaignReportStrategy.new(@campaign, @csv, true, CampaignReportStrategy::Mode::PER_DIAL, 
        @selected_voter_fields, @selected_custom_voter_fields, nil, nil)
        strategy.construct_csv.should eq([["ID", "First name", "Phone", "field1", "field2", "Caller", "Status", "Time Dialed", "Time Answered", "Time Ended", "Recording", "Q1", "Q12", "", "note1", "note2"], ["24566", "first", "39045098753", "value1", "value2", "a caller", "Answered", Time.at(1338292076).in_time_zone(@campaign.time_zone), Time.at(1338292476).in_time_zone(@campaign.time_zone), Time.at(1338293196).in_time_zone(@campaign.time_zone), "xyz.mp3", "Hey", "Wee", "Tree", "Test2", "Test1"]])
      end
      
      it "should create the csv for download all per lead" do
        caller = Factory(:caller, email: "abc@hui.com")       
        voter = Factory(:voter, account: @account, campaign: @campaign)     
        phone, custom_id, firstname = "39045098753", "24566", "first"
        voter.update_attributes(:Phone => phone, :CustomID => custom_id, :FirstName => firstname)        
        field1  = Factory(:custom_voter_field, :name => "field1", :account => @account)
        field2 = Factory(:custom_voter_field, :name => "field2", :account => @account)

        value1 = Factory(:custom_voter_field_value, :voter => voter, :custom_voter_field => field1, :value => "value1")
        value2 = Factory(:custom_voter_field_value, :voter => voter, :custom_voter_field => field2, :value => "value2")

        call_attempt = Factory(:call_attempt, voter: voter, status: CallAttempt::Status::SUCCESS, call_start: Time.at(1338292076), connecttime: Time.at(1338292476), call_end: Time.at(1338293196), recording_url: "xyz",campaign: @campaign)
        question1 = Factory(:question, text: "Q1", script: @script)
        question2 = Factory(:question, text: "Q12", script: @script)   
        answer1 = Factory(:answer, campaign: @campaign, question_id: question1.id , voter: voter, possible_response: Factory(:possible_response, question_id: question1.id, value: "Hey"), call_attempt: call_attempt)
        answer2 = Factory(:answer, campaign: @campaign, question_id: question2.id, voter: voter, possible_response: Factory(:possible_response, question_id: question2.id, value: "Wee"), call_attempt: call_attempt)           
        answer3 = Factory(:answer, campaign: @campaign, question_id: 13456, voter: voter, possible_response: Factory(:possible_response, question_id: 13456, value: "Tree"), call_attempt: call_attempt)                  
        note1 = Factory(:note, script: @script, note:"note1")
        note2 = Factory(:note, script: @script, note:"note2")
        note_response1 = Factory(:note_response, campaign: @campaign, note: note1 , voter: Factory(:voter), call_attempt: call_attempt, response: "Test2")
        note_response2 = Factory(:note_response, campaign: @campaign, note: note2, voter: Factory(:voter), call_attempt: call_attempt, response: "Test1")
        strategy = CallerCampaignReportStrategy.new(@campaign, @csv, true, CampaignReportStrategy::Mode::PER_LEAD, 
        @selected_voter_fields, @selected_custom_voter_fields, nil, nil)
        strategy.construct_csv.should eq([["ID", "First name", "Phone", "field1", "field2", "Caller", "Status", "Time Dialed", "Time Answered", "Time Ended", "Attempts","Recording", "Q1", "Q12", "", "note1", "note2"], ["24566", "first", "39045098753", "value1", "value2", "a caller", "Answered", Time.at(1338292076).in_time_zone(@campaign.time_zone), Time.at(1338292476).in_time_zone(@campaign.time_zone), Time.at(1338293196).in_time_zone(@campaign.time_zone), 1,"xyz.mp3", "Hey", "Wee", "Tree", "Test2", "Test1"]])
      end

   end
  
  
  
end
