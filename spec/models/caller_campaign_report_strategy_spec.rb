require "spec_helper"

describe CallerCampaignReportStrategy, :type => :model do

  describe "csv header" do
    before (:each) do
      @script = create(:script)
      @campaign = create(:campaign, script: @script)
      @csv = CSV.generate {}
      @selected_voter_fields = ["custom_id", "first_name", "middle_name"]
      @selected_custom_voter_fields = ["VAN", "Designation"]
    end

     it "should create csv headers" do
       strategy = CallerCampaignReportStrategy.new(@campaign, @csv, true, CampaignReportStrategy::Mode::PER_LEAD, @selected_voter_fields, @selected_custom_voter_fields, nil, nil)
       expect(strategy.csv_header).to eq(["ID", "First name", "Middle name", "VAN", "Designation", "Caller", "Status", "Time Call Dialed", "Time Call Answered", "Time Call Ended", "Call Duration (seconds)", "Time Transfer Started", "Time Transfer Ended", "Transfer Duration (minutes)", "Attempts", "Message Left", "Recording"])
     end

     it "should create csv headers and not have Attempts if per dial" do
       strategy = CallerCampaignReportStrategy.new(@campaign, @csv, true, CampaignReportStrategy::Mode::PER_DIAL, @selected_voter_fields, @selected_custom_voter_fields, nil, nil)
       expect(strategy.csv_header).to eq(["ID", "First name", "Middle name", "VAN", "Designation", "Caller", "Status", "Time Call Dialed", "Time Call Answered", "Time Call Ended", "Call Duration (seconds)", "Time Transfer Started", "Time Transfer Ended", "Transfer Duration (minutes)", "Message Left", "Recording"])
     end

     it "should manipulate headers" do
       selected_voter_fields = ["custom_id", "last_name", "first_name", "middle_name", "address", "city", "state", "zip_code", "country"]
       strategy = CallerCampaignReportStrategy.new(@campaign, @csv, true, CampaignReportStrategy::Mode::PER_LEAD, selected_voter_fields, @selected_custom_voter_fields, nil, nil)
       expect(strategy.csv_header).to eq(["ID", "Last name", "First name", "Middle name", "Address", "City", "State", "Zip code", "Country", "VAN", "Designation", "Caller", "Status", "Time Call Dialed", "Time Call Answered", "Time Call Ended", "Call Duration (seconds)", "Time Transfer Started", "Time Transfer Ended", "Transfer Duration (minutes)", "Attempts", "Message Left", "Recording"])
     end

     it "should create csv headers with question texts" do
       question1 = create(:question, text: "Q1", script: @script)
       question2 = create(:question, text: "Q12", script: @script)
       answer1 = create(:answer, campaign: @campaign, question: question1 , voter: create(:voter), possible_response: create(:possible_response))
       answer2 = create(:answer, campaign: @campaign, question: question2, voter: create(:voter), possible_response: create(:possible_response))
       strategy = CallerCampaignReportStrategy.new(@campaign, @csv, true, CampaignReportStrategy::Mode::PER_DIAL, @selected_voter_fields, @selected_custom_voter_fields, nil, nil)
       expect(strategy.csv_header).to eq(["ID", "First name", "Middle name", "VAN", "Designation", "Caller", "Status", "Time Call Dialed", "Time Call Answered", "Time Call Ended", "Call Duration (seconds)", "Time Transfer Started", "Time Transfer Ended", "Transfer Duration (minutes)", "Message Left", "Recording", "Q1", "Q12"])
     end

     it "should create csv headers with notes " do
       note1 = create(:note, script: @script, note:"note1")
       note2 = create(:note, script: @script, note:"note2")
       note_response1 = create(:note_response, campaign: @campaign, note: note1 , voter: create(:voter))
       note_response2 = create(:note_response, campaign: @campaign, note: note2, voter: create(:voter))
       strategy = CallerCampaignReportStrategy.new(@campaign, @csv, true, CampaignReportStrategy::Mode::PER_DIAL, @selected_voter_fields, @selected_custom_voter_fields, nil, nil)
       expect(strategy.csv_header).to eq(["ID", "First name", "Middle name", "VAN", "Designation", "Caller", "Status", "Time Call Dialed", "Time Call Answered", "Time Call Ended", "Call Duration (seconds)", "Time Transfer Started", "Time Transfer Ended", "Transfer Duration (minutes)", "Message Left", "Recording", "note1", "note2"])
     end

     it "should create csv headers with questions and  notes " do
       question1 = create(:question, text: "Q1", script: @script)
       question2 = create(:question, text: "Q12", script: @script)
       answer1 = create(:answer, campaign: @campaign, question: question1 , voter: create(:voter), possible_response: create(:possible_response))
       answer2 = create(:answer, campaign: @campaign, question: question2, voter: create(:voter), possible_response: create(:possible_response))

       note1 = create(:note, script: @script, note:"note1")
       note2 = create(:note, script: @script, note:"note2")
       note_response1 = create(:note_response, campaign: @campaign, note: note1 , voter: create(:voter))
       note_response2 = create(:note_response, campaign: @campaign, note: note2, voter: create(:voter))
       strategy = CallerCampaignReportStrategy.new(@campaign, @csv, true, CampaignReportStrategy::Mode::PER_DIAL, @selected_voter_fields, @selected_custom_voter_fields, nil, nil)
       expect(strategy.csv_header).to eq(["ID", "First name", "Middle name", "VAN", "Designation", "Caller", "Status", "Time Call Dialed", "Time Call Answered", "Time Call Ended", "Call Duration (seconds)", "Time Transfer Started", "Time Transfer Ended", "Transfer Duration (minutes)", "Message Left", "Recording", "Q1", "Q12", "note1", "note2"])
     end
  end

  describe "call_attempt_info" do
    before (:each) do
      @script = create(:script)
      @campaign = create(:campaign, script: @script)
      @csv = CSV.generate {}
      @selected_voter_fields = ["CustomID", "FirstName", "MiddleName"]
      @selected_custom_voter_fields = ["VAN", "Designation"]
    end

    it "should create the basic info for per dial" do
      caller       = create(:caller, username: "abc@hui.com")
      voter        = create(:voter)
      recording    = create(:recording)
      call_attempt = create(:call_attempt, {
        voter: voter,
        household: voter.household,
        status: CallAttempt::Status::SUCCESS,
        call_start: Time.at(1338292076),
        connecttime: Time.at(1338292476),
        call_end: Time.at(1338293196),
        recording_url: "xyz",
        caller: caller,
        recording_delivered_manually: false,
        recording_id: recording.id
      })
      attempt_numbers = {
        voter.household.id => {
          cnt: 12,
          last_id: call_attempt.id
        }
      }

      voicemail_history = {
        voter.household.id => {
          message_left_text: 'Yes: automatically'
        }
      }
      strategy = CallerCampaignReportStrategy.new(@campaign, @csv, true, CampaignReportStrategy::Mode::PER_DIAL, @selected_voter_fields, @selected_custom_voter_fields, nil, nil)
      actual = strategy.call_attempt_info(call_attempt.attributes, {
                call_attempt.caller_id => call_attempt.caller.known_as
               }, attempt_numbers, {}, voter.attributes, voicemail_history)
      expected = [
        "a caller",
        "Answered",
        Time.at(1338292076).in_time_zone(@campaign.time_zone),
        Time.at(1338292476).in_time_zone(@campaign.time_zone),
        Time.at(1338293196).in_time_zone(@campaign.time_zone),
        nil, # call duration
        'N/A', # transfer attempt start
        'N/A', # transfer attempt end
        'N/A', # transfer attempt duration
        "Yes: automatically",
        "xyz.mp3"
      ]
      expect(actual).to eq expected
    end

    it "should create the basic info for per lead" do
      caller = create(:caller, username: "abc@hui.com")
      voter = create(:voter)
      call_attempt = create(:call_attempt, {
        voter: voter,
        household: voter.household,
        status: CallAttempt::Status::SUCCESS,
        call_start: Time.at(1338292076),
        connecttime: Time.at(1338292476),
        call_end: Time.at(1338293196),
        recording_url: "xyz",
        caller: caller
      })
      attempt_numbers = {
        voter.household.id => {
          cnt: 12,
          last_id: call_attempt.id
        }
      }
      voicemail_history = {
        voter.household.id => {
          message_left_text: 'No'
        }
      }
      strategy = CallerCampaignReportStrategy.new(@campaign, @csv, true, CampaignReportStrategy::Mode::PER_LEAD, @selected_voter_fields, @selected_custom_voter_fields, nil, nil)
      actual = strategy.call_attempt_info(call_attempt.attributes, {
        call_attempt.caller_id => call_attempt.caller.known_as
      }, attempt_numbers, {}, voter.attributes, voicemail_history)
      expected = [
        "a caller",
        "Answered",
        Time.at(1338292076).in_time_zone(@campaign.time_zone),
        Time.at(1338292476).in_time_zone(@campaign.time_zone),
        Time.at(1338293196).in_time_zone(@campaign.time_zone),
        nil, # call duration
        'N/A', # transfer attempt start
        'N/A', # transfer attempt end
        'N/A', # transfer attempt duration
        attempt_numbers[voter.household.id][:cnt],
        voicemail_history[voter.household.id][:message_left_text],
        "xyz.mp3"
      ]
      expect(actual).to eq expected
    end

  end

  describe "call_attempt_details" do
    let(:voter) { create(:voter) }

    before (:each) do
      @script = create(:script)
      @campaign = create(:campaign, script: @script)
      @csv = CSV.generate {}
      @selected_voter_fields = ["CustomID", "FirstName", "MiddleName"]
      @selected_custom_voter_fields = ["VAN", "Designation"]
      @caller = create(:caller)
      question1 = create(:question, text: "Q1", script: @script)
      question2 = create(:question, text: "Q12", script: @script)
      possible_response1 = create(:possible_response, question_id: question1.id, value: "Hey")
      possible_response2 = create(:possible_response, question_id: question2.id, value: "Wee")
      answer1 = create(:answer, campaign: @campaign, question_id: question1.id , voter: voter, possible_response: possible_response1, call_attempt: call_attempt)
      answer2 = create(:answer, campaign: @campaign, question_id: question2.id, voter: voter, possible_response: possible_response2, call_attempt: call_attempt)
      note1 = create(:note, script: @script, note:"note1")
      note2 = create(:note, script: @script, note:"note2")
      note_response1 = create(:note_response, campaign: @campaign, note: note1 , voter: create(:voter), call_attempt: call_attempt, response: "Test2")
      note_response2 = create(:note_response, campaign: @campaign, note: note2, voter: create(:voter), call_attempt: call_attempt, response: "Test1")
      @strategy = CallerCampaignReportStrategy.new(@campaign, @csv, true, CampaignReportStrategy::Mode::PER_DIAL, @selected_voter_fields, @selected_custom_voter_fields, nil, nil)
      @answers = @strategy.get_answers([call_attempt.id])[call_attempt.id]
      @note_responses = @strategy.get_note_responses([call_attempt.id])[call_attempt.id]
      @possible_responses = {possible_response1.id => possible_response1.value, possible_response2.id => possible_response2.value}
    end

    context "success" do
      let(:call_attempt) do
        create(:call_attempt,
                voter: voter,
                household: voter.household,
                status: CallAttempt::Status::SUCCESS,
                call_start: Time.at(1338292076),
                connecttime: Time.at(1338292476),
                call_end: Time.at(1338293196),
                recording_url: "xyz",
                caller: @caller
               )
      end

      let(:attempt_numbers) do
        {
          voter.household.id => {
            cnt: 12,
            last_id: call_attempt.id
          }
        }
      end

      let(:voicemail_history) do
        {
          voter.household.id => {
            message_left_text: 'No'
          }
        }
      end

      it "should create the csv row" do
        actual = @strategy.call_attempt_details(call_attempt.attributes, @answers, @note_responses, {
          call_attempt.caller_id => call_attempt.caller.known_as
        }, attempt_numbers, @possible_responses, {}, voter.attributes, voicemail_history)
        expected = [
          "a caller",
          "Answered",
          Time.at(1338292076).in_time_zone(@campaign.time_zone),
          Time.at(1338292476).in_time_zone(@campaign.time_zone),
          Time.at(1338293196).in_time_zone(@campaign.time_zone),
          nil, # call duration
          'N/A', # transfer attempt start
          'N/A', # transfer attempt end
          'N/A', # transfer attempt duration
          voicemail_history[voter.household.id][:message_left_text],
          "xyz.mp3",
          "Hey",
          "Wee",
          "Test2",
          "Test1"
        ]
        expect(actual).to eq expected
      end
    end

    context "ringing" do
      let(:call_attempt) { create(:call_attempt, voter: voter, status: CallAttempt::Status::RINGING, caller: @caller) }
      it "should create the csv row convert ringing to not dialed" do
        expect(@strategy.call_attempt_details(call_attempt.attributes, @answers, @note_responses, {call_attempt.caller_id => call_attempt.caller.known_as}, {voter.id => 1}, @possible_responses)).to eq([nil, "Not Dialed", "", "", "", "", "", [], []])
      end
    end

    context "ready" do
      let(:call_attempt) { create(:call_attempt, voter: voter, status: CallAttempt::Status::READY, caller: @caller) }
      it "should create the csv row convert ready to not dialed" do
        expect(@strategy.call_attempt_details(call_attempt.attributes, @answers, @note_responses, {call_attempt.caller_id => call_attempt.caller.known_as}, {voter.id => 1}, @possible_responses)).to eq([nil, "Not Dialed", "", "", "", "", "", [], []])
      end
    end
  end

  describe "csv_for_call_attempt" do
    before (:each) do
      @account = create(:account)
      @script = create(:script, account: @account)
      @campaign = create(:campaign, script: @script, account: @account)
      @csv = CSV.generate {}
      @selected_voter_fields = ["CustomID", "FirstName", "Phone"]
      @selected_custom_voter_fields = ["field1", "field2"]
    end

    it "should create the csv row when a question is deleted" do
      caller = create(:caller, username: "abc@hui.com")
      voter = create(:voter, account: @account)
      phone, custom_id, firstname = "39045098753", "24566", "first"
      voter.update_attributes(:phone => phone, :custom_id => custom_id, :first_name => firstname)
      field1  = create(:custom_voter_field, :name => "field1", :account => @account)
      field2 = create(:custom_voter_field, :name => "field2", :account => @account)

      value1 = create(:custom_voter_field_value, :voter => voter, :custom_voter_field => field1, :value => "value1")
      value2 = create(:custom_voter_field_value, :voter => voter, :custom_voter_field => field2, :value => "value2")

      call_attempt = create(:call_attempt, {
        voter: voter,
        household: voter.household,
        status: CallAttempt::Status::SUCCESS,
        call_start: Time.at(1338292076),
        connecttime: Time.at(1338292476),
        call_end: Time.at(1338293196),
        recording_url: "xyz",
        caller: caller
      })
      question1 = create(:question, text: "Q1", script: @script)
      question2 = create(:question, text: "Q12", script: @script)
      possible_response1 = create(:possible_response, question_id: question1.id, value: "Hey")
      possible_response2 = create(:possible_response, question_id: question2.id, value: "Wee")
      possible_response3 = create(:possible_response, question_id: 13456, value: "Tree")
      answer1 = create(:answer, campaign: @campaign, question_id: question1.id , voter: voter, possible_response: possible_response1, call_attempt: call_attempt)
      answer2 = create(:answer, campaign: @campaign, question_id: question2.id, voter: voter, possible_response: possible_response2, call_attempt: call_attempt)
      answer3 = create(:answer, campaign: @campaign, question_id: 13456, voter: voter, possible_response: possible_response3, call_attempt: call_attempt)
      note1 = create(:note, script: @script, note:"note1")
      note2 = create(:note, script: @script, note:"note2")
      note_response1 = create(:note_response, campaign: @campaign, note: note1 , voter: create(:voter), call_attempt: call_attempt, response: "Test2")
      note_response2 = create(:note_response, campaign: @campaign, note: note2, voter: create(:voter), call_attempt: call_attempt, response: "Test1")
      strategy = CallerCampaignReportStrategy.new(@campaign, @csv, true, CampaignReportStrategy::Mode::PER_DIAL,
      @selected_voter_fields, @selected_custom_voter_fields, nil, nil)
      answers = strategy.get_answers([call_attempt.id])[call_attempt.id]
      responses = strategy.get_note_responses([call_attempt.id])[call_attempt.id]
      possible_responses_data = {
        possible_response1.id => 'Hey',
        possible_response2.id => 'Wee',
        possible_response3.id => 'Tree'
      }
      attempt_numbers = {
        voter.household.id => {
          cnt: 12,
          last_id: call_attempt.id
        }
      }
      voicemail_history = {
        voter.household.id => {
          message_left_text: 'Yes: automatically'
        }
      }
      actual = strategy.call_attempt_details(call_attempt, answers, responses, {
        call_attempt.caller_id => call_attempt.caller.known_as
      }, attempt_numbers, possible_responses_data, {}, voter.attributes, voicemail_history)
      expected = [
        "a caller",
        "Answered",
        Time.at(1338292076).in_time_zone(@campaign.time_zone),
        Time.at(1338292476).in_time_zone(@campaign.time_zone),
        Time.at(1338293196).in_time_zone(@campaign.time_zone),
        nil, # call duration
        'N/A', # transfer attempt start
        'N/A', # transfer attempt end
        'N/A', # transfer attempt duration
        voicemail_history[voter.household.id][:message_left_text],
        "xyz.mp3",
        "Hey",
        "Wee",
        "Tree",
        "Test2",
        "Test1"
      ]
      expect(actual).to eq expected
    end
  end

  describe "voter fields" do
    let(:account) { create(:account) }
    let(:voter) { create(:voter, :account => account) }
    let(:field1) { create(:custom_voter_field, :name => "field1", :account => account) }
    let(:field2) { create(:custom_voter_field, :name => "field2", :account => account) }
    let(:field3) { create(:custom_voter_field, :name => "field3", :account => account) }

    before (:each) do
      @script = create(:script)
      @campaign = create(:campaign, script: @script)
      @csv = CSV.generate {}
      @selected_voter_fields = ["custom_id", "first_name", "middle_name"]
      @selected_custom_voter_fields = ["field1", "field2", "field3"]
      @strategy = CallerCampaignReportStrategy.new(@campaign, @csv, true, CampaignReportStrategy::Mode::PER_LEAD, @selected_voter_fields, @selected_custom_voter_fields, nil, nil)
    end

    it "lists voters custom fields with selected field names" do
      value1 = create(:custom_voter_field_value, :voter => voter, :custom_voter_field => field1, :value => "value1")
      value2 = create(:custom_voter_field_value, :voter => voter, :custom_voter_field => field2, :value => "value2")
      data = {'field1' => 'value1', 'field2' => 'value2'}
      expect(@strategy.selected_custom_fields(voter.attributes, [field1.name, field2.name], data)).to eq([value1.value, value2.value])
      expect(@strategy.selected_custom_fields(voter.attributes, [field2.name, field1.name], data)).to eq([value2.value, value1.value])
      expect(@strategy.selected_custom_fields(voter.attributes, nil, data)).to eq([])
    end

    it "lists voters custom fields with selected field names" do
      data = {'field2' => 'value2'}
      value2 = create(:custom_voter_field_value, :voter => voter, :custom_voter_field => field2, :value => "value2")
      expect(@strategy.selected_custom_fields(voter.attributes, [field1.name, field2.name, field3.name], data)).to eq([nil, value2.value, nil])
    end

    it "lists selected voter fields" do
      phone, custom_id, firstname = "39045098753", "24566", "first"
      voter.update_attributes(:phone => phone, :custom_id => custom_id, :first_name => firstname, :last_name => nil)
      expect(@strategy.selected_fields(voter.attributes, ["phone", "first_name", "last_name"])).to eq([phone, firstname, nil])
      expect(@strategy.selected_fields(voter.attributes, ["phone", "last_name", "first_name"])).to eq([phone, nil, firstname])
    end

    it "selects phone number if there are no selected fields" do
      phone, custom_id, firstname = "39045098753", "24566", "first"
      voter.update_attributes(:phone => phone, :custom_id => custom_id, :first_name => firstname)
      expect(@strategy.selected_fields(voter.attributes)).to eq([phone])
    end

  end

  describe "csv_for" do
    before (:each) do
      @account = create(:account)
      @script = create(:script, account: @account)
      @campaign = create(:campaign, script: @script, account: @account)
      @csv = CSV.generate {}
      @selected_voter_fields = ["custom_id", "first_name", "phone"]
      @selected_custom_voter_fields = ["field1", "field2"]
    end

    it "should create the csv row when a question is deleted" do
       caller = create(:caller, username: "abc@hui.com")
       voter = create(:voter, account: @account)
       phone, custom_id, firstname = "39045098753", "24566", "first"
       voter.update_attributes(:phone => phone, :custom_id => custom_id, :first_name => firstname)
       field1  = create(:custom_voter_field, :name => "field1", :account => @account)
       field2 = create(:custom_voter_field, :name => "field2", :account => @account)

       value1 = create(:custom_voter_field_value, :voter => voter, :custom_voter_field => field1, :value => "value1")
       value2 = create(:custom_voter_field_value, :voter => voter, :custom_voter_field => field2, :value => "value2")

       call_attempt = create(:call_attempt, voter: voter, status: CallAttempt::Status::SUCCESS, call_start: Time.at(1338292076), connecttime: Time.at(1338292476), call_end: Time.at(1338293196), recording_url: "xyz")
       question1 = create(:question, text: "Q1", script: @script)
       question2 = create(:question, text: "Q12", script: @script)
       answer1 = create(:answer, campaign: @campaign, question_id: question1.id , voter: voter, possible_response: create(:possible_response, question_id: question1.id, value: "Hey"), call_attempt: call_attempt)
       answer2 = create(:answer, campaign: @campaign, question_id: question2.id, voter: voter, possible_response: create(:possible_response, question_id: question2.id, value: "Wee"), call_attempt: call_attempt)
       answer3 = create(:answer, campaign: @campaign, question_id: 13456, voter: voter, possible_response: create(:possible_response, question_id: 13456, value: "Tree"), call_attempt: call_attempt)
       note1 = create(:note, script: @script, note:"note1")
       note2 = create(:note, script: @script, note:"note2")
       note_response1 = create(:note_response, campaign: @campaign, note: note1 , voter: create(:voter), call_attempt: call_attempt, response: "Test2")
       note_response2 = create(:note_response, campaign: @campaign, note: note2, voter: create(:voter), call_attempt: call_attempt, response: "Test1")
       strategy = CallerCampaignReportStrategy.new(@campaign, @csv, true, CampaignReportStrategy::Mode::PER_DIAL,
       @selected_voter_fields, @selected_custom_voter_fields, nil, nil)
       expect(strategy.csv_for(voter, {'field1' => 'value1', 'field2' => 'value2'})).to eq(["24566", "first", "39045098753", "value1", "value2", [nil, "Not Dialed", "", "", "", "", [], []]])
     end

  end

  describe "construct_csv" do
     before (:each) do
       @account = create(:account)
       @script = create(:script, account: @account)
       @campaign = create(:campaign, script: @script, account: @account)
       @csv = []
       @selected_voter_fields = ["custom_id", "first_name", "phone"]
       @selected_custom_voter_fields = ["field1", "field2"]
     end

     it "should create the csv for download all per dial" do
        caller = create(:caller, username: "abc@hui.com")
        voter = create(:voter, account: @account, campaign: @campaign)
        phone, custom_id, firstname = "39045098753", "24566", "first"
        voter.update_attributes(:custom_id => custom_id, :first_name => firstname)
        voter.household.update_attributes(phone: phone)
        field1  = create(:custom_voter_field, :name => "field1", :account => @account)
        field2 = create(:custom_voter_field, :name => "field2", :account => @account)

        value1 = create(:custom_voter_field_value, :voter => voter, :custom_voter_field => field1, :value => "value1")
        value2 = create(:custom_voter_field_value, :voter => voter, :custom_voter_field => field2, :value => "value2")

        call_attempt = create(:call_attempt, {
          voter: voter,
          household: voter.household,
          status: CallAttempt::Status::SUCCESS,
          call_start: Time.at(1338292076),
          connecttime: Time.at(1338292476),
          call_end: Time.at(1338293196),
          recording_url: "xyz",
          campaign: @campaign,
          caller: caller,
          recording_id: 42,
          recording_delivered_manually: false
        })
        transfer_attempt = create(:transfer_attempt, {
          tStartTime: Time.at(1338292576),
          tEndTime: Time.at(1338292776),
          tDuration: '45',
          call_attempt: call_attempt
        })
        question1 = create(:question, text: "Q1", script: @script)
        question2 = create(:question, text: "Q12", script: @script)
        answer1 = create(:answer, campaign: @campaign, question_id: question1.id , voter: voter, possible_response: create(:possible_response, question_id: question1.id, value: "Hey"), call_attempt: call_attempt)
        answer2 = create(:answer, campaign: @campaign, question_id: question2.id, voter: voter, possible_response: create(:possible_response, question_id: question2.id, value: "Wee"), call_attempt: call_attempt)
        answer3 = create(:answer, campaign: @campaign, question_id: 13456, voter: voter, possible_response: create(:possible_response, question_id: 13456, value: "Tree"), call_attempt: call_attempt)
        note1 = create(:note, script: @script, note:"note1")
        note2 = create(:note, script: @script, note:"note2")
        note_response1 = create(:note_response, campaign: @campaign, note: note1 , voter: create(:voter), call_attempt: call_attempt, response: "Test2")
        note_response2 = create(:note_response, campaign: @campaign, note: note2, voter: create(:voter), call_attempt: call_attempt, response: "Test1")
        strategy = CallerCampaignReportStrategy.new(@campaign, @csv, true, CampaignReportStrategy::Mode::PER_DIAL,
        @selected_voter_fields, @selected_custom_voter_fields, nil, nil)
        expected = [
          [
            "ID",
            "First name",
            "Phone",
            "field1",
            "field2",
            "Caller",
            "Status",
            "Time Call Dialed",
            "Time Call Answered",
            "Time Call Ended",
            "Call Duration (seconds)",
            "Time Transfer Started",
            "Time Transfer Ended",
            "Transfer Duration (minutes)",
            "Message Left",
            "Recording",
            "Q1",
            "Q12",
            "",
            "note1",
            "note2"
          ],
          [
            custom_id,
            firstname,
            phone,
            "value1",
            "value2",
            "a caller",
            "Answered",
            Time.at(1338292076).in_time_zone(@campaign.time_zone),
            Time.at(1338292476).in_time_zone(@campaign.time_zone),
            Time.at(1338293196).in_time_zone(@campaign.time_zone),
            nil, # call duration
            transfer_attempt.tStartTime.in_time_zone(@campaign.time_zone),
            transfer_attempt.tEndTime.in_time_zone(@campaign.time_zone),
            1,
            "Yes: automatically",
            "xyz.mp3",
            "Hey",
            "Wee",
            "Tree",
            "Test2",
            "Test1"
          ]
        ]
        expect(strategy.construct_csv).to eq expected
      end

      it "should create the csv for download all per lead" do
        caller = create(:caller, username: "abc@hui.com")
        voter = create(:voter, account: @account, campaign: @campaign)
        phone, custom_id, firstname = "39045098753", "24566", "first"
        voter.update_attributes(:custom_id => custom_id, :first_name => firstname)
        voter.household.update_attributes(:phone => phone)
        field1  = create(:custom_voter_field, :name => "field1", :account => @account)
        field2 = create(:custom_voter_field, :name => "field2", :account => @account)

        value1 = create(:custom_voter_field_value, :voter => voter, :custom_voter_field => field1, :value => "value1")
        value2 = create(:custom_voter_field_value, :voter => voter, :custom_voter_field => field2, :value => "value2")

        call_attempt = create(:call_attempt, {
          voter: voter,
          household: voter.household,
          status: CallAttempt::Status::SUCCESS,
          call_start: Time.at(1338292076),
          connecttime: Time.at(1338292476),
          call_end: Time.at(1338293196),
          recording_url: "xyz",
          campaign: @campaign,
          caller: caller,
          recording_id: 42,
          recording_delivered_manually: false
        })
        question1      = create(:question, text: "Q1", script: @script)
        question2      = create(:question, text: "Q12", script: @script)
        answer1        = create(:answer, campaign: @campaign, question_id: question1.id , voter: voter, possible_response: create(:possible_response, question_id: question1.id, value: "Hey"), call_attempt: call_attempt)
        answer2        = create(:answer, campaign: @campaign, question_id: question2.id, voter: voter, possible_response: create(:possible_response, question_id: question2.id, value: "Wee"), call_attempt: call_attempt)
        answer3        = create(:answer, campaign: @campaign, question_id: 13456, voter: voter, possible_response: create(:possible_response, question_id: 13456, value: "Tree"), call_attempt: call_attempt)
        note1          = create(:note, script: @script, note:"note1")
        note2          = create(:note, script: @script, note:"note2")
        note_response1 = create(:note_response, campaign: @campaign, note: note1 , voter: create(:voter), call_attempt: call_attempt, response: "Test2")
        note_response2 = create(:note_response, campaign: @campaign, note: note2, voter: create(:voter), call_attempt: call_attempt, response: "Test1")

        strategy = CallerCampaignReportStrategy.new(
          @campaign, @csv, true, CampaignReportStrategy::Mode::PER_LEAD,
          @selected_voter_fields, @selected_custom_voter_fields, nil, nil
        )
        expected = [
          [
            "ID",
            "First name",
            "Phone",
            "field1",
            "field2",
            "Caller",
            "Status",
            "Time Call Dialed",
            "Time Call Answered",
            "Time Call Ended",
            "Call Duration (seconds)",
            "Time Transfer Started",
            "Time Transfer Ended",
            "Transfer Duration (minutes)",
            "Attempts",
            "Message Left",
            "Recording",
            "Q1",
            "Q12",
            "",
            "note1",
            "note2"
          ],
          [
            "24566",
            "first",
            "39045098753",
            "value1",
            "value2",
            "a caller",
            "Answered",
            Time.at(1338292076).in_time_zone(@campaign.time_zone),
            Time.at(1338292476).in_time_zone(@campaign.time_zone),
            Time.at(1338293196).in_time_zone(@campaign.time_zone),
            nil, # call duration
            'N/A', # transfer attempt start
            'N/A', # transfer attempt end
            'N/A', # transfer attempt duration
            1,
            "Yes: automatically",
            "xyz.mp3",
            "Hey",
            "Wee",
            "Tree",
            "Test2",
            "Test1"
          ]
        ]
        expect(strategy.construct_csv).to eq expected
      end
   end
end
