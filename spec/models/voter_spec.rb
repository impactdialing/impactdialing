require "spec_helper"

describe Voter do
  include Rails.application.routes.url_helpers

  it "can share the same number" do
    Factory(:voter, :Phone => '92345623434')
    Factory(:voter, :Phone => '92345623434')
    Voter.all.size.should == 2
  end

  it "should list existing entries in a campaign having the given phone number" do
    lambda {
      Factory(:voter, :Phone => '0123456789', :campaign_id => 99)
    }.should change {
      Voter.existing_phone_in_campaign('0123456789', 99).count
    }.by(1)
  end

  it "lists voters not called" do
    voter1 = Factory(:voter, :campaign => Factory(:campaign), :status=> Voter::Status::NOTCALLED)
    voter2 = Factory(:voter, :campaign => Factory(:campaign), :status=> Voter::Status::NOTCALLED)
    Factory(:voter, :campaign => Factory(:campaign), :status=> "Random")
    Voter.by_status(Voter::Status::NOTCALLED).should == [voter1, voter2]
  end

  it "returns only active voters" do
    active_voter = Factory(:voter, :active => true)
    inactive_voter = Factory(:voter, :active => false)
    Voter.active.should == [active_voter]
  end

  it "returns voters that have responded" do
    Factory(:voter)
    3.times { Factory(:voter, :result_date => Time.now) }
    Voter.answered.size.should == 3
  end

  it "returns voters that have responded within a date range" do
    Factory(:voter)
    v1 = Factory(:voter, :result_date => DateTime.now)
    v2 = Factory(:voter, :result_date => 1.day.ago)
    v3 = Factory(:voter, :result_date => 2.days.ago)
    Voter.answered_within(2.days.ago, 0.days.ago).should == [v1, v2, v3]
    Voter.answered_within(2.days.ago, 1.day.ago).should == [v2, v3]
    Voter.answered_within(1.days.ago, 1.days.ago).should == [v2]
  end

  it "conferences with a caller" do
    voter = Factory(:voter)
    caller = Factory(:caller_session)

    voter.conference(caller)
    caller.reload.voter_in_progress.should == voter
  end

  describe "Dialing" do
    let(:campaign) { Factory(:campaign) }
    let(:voter) { Factory(:voter, :campaign => campaign) }

    it "is dialed" do
      call_attempt = Factory(:call_attempt)
      voter.should_receive(:new_call_attempt).and_return(call_attempt)
      callback_url = twilio_callback_url(:call_attempt_id => call_attempt, :host => Settings.host, :port => Settings.port)
      fallback_url = twilio_report_error_url(:call_attempt_id => call_attempt, :host => Settings.host, :port => Settings.port)
      callended_url = twilio_call_ended_url(:call_attempt_id => call_attempt, :host => Settings.host, :port => Settings.port)
      Twilio::Call.should_receive(:make).with(
          voter.campaign.caller_id,
          voter.Phone,
          callback_url,
          'FallbackUrl' => fallback_url,
          'StatusCallback' => callended_url,
          'Timeout' => '20',
          'IfMachine' => 'Hangup'
      ).and_return({"TwilioResponse" => {"Call" => {"Sid" => "sid"}}})
      voter.dial
    end

    it "records a call attempt for a dialed voter" do
      Twilio::Call.stub!(:make).and_return({"TwilioResponse" => {"Call" => {"Sid" => "abcd"}}})
      lambda {
        voter.dial
      }.should change {
        voter.call_attempts.count
      }.by(1)

      call_attempt = voter.call_attempts.first
      call_attempt.campaign.should == campaign
      call_attempt.dialer_mode.should == "robo"
      call_attempt.status.should == CallAttempt::Status::RINGING
      voter.last_call_attempt.should == call_attempt
    end

    it "updates the sid for a dialed voter" do
      sid = "xyzzyspoonshift1"
      Twilio::Call.stub!(:make).and_return({"TwilioResponse" => {"Call" => {"Sid" => sid}}})
      voter.dial
      voter.call_attempts.last.sid.should == sid
    end

    it "records users to call back" do
      voter1 = Factory(:voter)
      Voter.to_callback.should == []
      voter2 = Factory(:voter, :call_back =>true)
      Voter.to_callback.should == [voter2]
    end
  end

  describe "predictive dialing" do
    let(:campaign) { Factory(:campaign, :robo => false, :predictive_type => 'algorithm1', answering_machine_detect: true) }
    let(:voter) { Factory(:voter, :campaign => campaign) }
    let(:client) { mock(:client).tap { |client| Twilio::REST::Client.stub(:new).and_return(client) } }

    context 'making calls' do
      before(:each) do
        Twilio::Call.should_receive(:make).with(anything, voter.Phone, anything, {'StatusCallback'=> anything, 'IfMachine' => 'Continue', 'Timeout' => anything}).and_return({"TwilioResponse" => {"Call" => {"Sid" => "sid"}}})
      end

      it "is dialed" do
        caller_session = Factory(:caller_session, :available_for_call => true, :on_call => true, campaign: campaign)
        voter.dial_predictive
        call_attempt = CallAttempt.first
        call_attempt.sid.should == "sid"
        call_attempt.status.should == CallAttempt::Status::RINGING
      end

      it "updates voter attributes" do
        caller_session = Factory(:caller_session, :available_for_call => true, :on_call => true, campaign: campaign)
        voter.dial_predictive
        call_attempt = voter.call_attempts.last
        voter.last_call_attempt.should == call_attempt
        time_now = Time.now
        Time.stub!(:now).and_return(time_now)
        DateTime.parse(voter.last_call_attempt_time.to_s).should == DateTime.parse(time_now.utc.to_s)
      end

      it "updates the call_attempts campaign" do
        caller_session = Factory(:caller_session, :available_for_call => true, :on_call => true, campaign: campaign)
        voter.dial_predictive
        call_attempt = voter.call_attempts.last
        call_attempt.campaign.should == voter.campaign
      end
    end

    it "dials the voter and hangs up on answering machine when not using recordings" do
      Twilio::Call.should_receive(:make).with(anything, voter.Phone, anything, {'StatusCallback'=> anything, 'IfMachine' => 'Continue', 'Timeout' => anything}).and_return({"TwilioResponse" => {"Call" => {"Sid" => "sid"}}})
      campaign.use_recordings = false
      voter.dial_predictive
    end

    it "dials the voter and continues on answering machine when using recordings" do
      Twilio::Call.should_receive(:make).with(anything, voter.Phone, anything, {'StatusCallback'=> anything, 'IfMachine' => 'Continue', 'Timeout' => anything}).and_return({"TwilioResponse" => {"Call" => {"Sid" => "sid"}}})
      voter.campaign = campaign
      voter.dial_predictive
    end

    it "dials the voter with the campaigns answer detection timeout" do
      campaign.use_recordings = true
      campaign.answer_detection_timeout = "10"
      Twilio::Call.should_receive(:make).with(anything, voter.Phone, anything, {'StatusCallback'=> anything, 'IfMachine' => 'Continue', 'Timeout' => anything}).and_return({"TwilioResponse" => {"Call" => {"Sid" => "sid"}}})
      voter.campaign = campaign
      voter.dial_predictive
    end
    
    it "dials the voter without IFMachine if AMD detection turned off" do
      campaign1 = Factory(:campaign, :robo => false, :predictive_type => 'algorithm1', answering_machine_detect: false)
      Twilio::Call.should_receive(:make).with(anything, voter.Phone, anything, {'StatusCallback'=> anything, 'Timeout' => anything}).and_return({"TwilioResponse" => {"Call" => {"Sid" => "sid"}}})
      voter.campaign = campaign1
      voter.dial_predictive
    end
    

    it "checks, whether voter is called or not" do
      voter1 = Factory(:voter, :status => "not called")
      voter2 = Factory(:voter, :status => "success")
      voter1.not_yet_called?("not called").should be_true
      voter2.not_yet_called?("not called").should be_false
    end

    it "checks, call attemp made before 3 hours or not" do
      voter1 = Factory(:voter, :last_call_attempt_time => 4.hours.ago, :call_back => true)
      voter2 = Factory(:voter, :last_call_attempt_time => 2.hours.ago, :call_back => true)
      voter1.call_attempted_before?(3.hours).should be_true
      voter2.call_attempted_before?(3.hours).should be_false
      voter2.call_attempted_before?(10.minutes).should be_true
    end

    it "returns all the voters to be call" do
      campaign = Factory(:campaign)
      voter_list1 = Factory(:voter_list)
      voter_list2 = Factory(:voter_list)
      active_list_ids = [voter_list1.id, voter_list2.id]
      status = "not called"
      voter1 = Factory(:voter, :campaign => campaign, :voter_list => voter_list1)
      voter2 = Factory(:voter, :campaign => campaign, :voter_list => voter_list1, last_call_attempt_time: 2.hours.ago, status: CallAttempt::Status::VOICEMAIL)
      voter3 = Factory(:voter, :campaign => campaign, :voter_list => voter_list2)
      voter4 = Factory(:voter, :voter_list => voter_list1)
      voter5 = Factory(:voter, :campaign => campaign)
      Voter.to_be_called(campaign.id, active_list_ids, status, 3).length.should == 2
    end

    it "return voters, to whoom called just now, but not replied " do
      campaign = Factory(:campaign)
      voter_list1 = Factory(:voter_list)
      voter_list2 = Factory(:voter_list)
      active_list_ids = [voter_list1.id, voter_list2.id]
      status = "not called"
      voter1 = Factory(:voter, :campaign => campaign, :call_back => true, :voter_list => voter_list1, :last_call_attempt_time => 2.hours.ago)
      voter2 = Factory(:voter, :campaign => campaign, :call_back => true, :voter_list => voter_list2, :last_call_attempt_time => 1.hours.ago)
      voter3 = Factory(:voter, :campaign => campaign, :call_back => true, :voter_list => voter_list2, :last_call_attempt_time => 30.minutes.ago)
      voter4 = Factory(:voter, :campaign => campaign, :call_back => false, :voter_list => voter_list2, :last_call_attempt_time => 50.minutes.ago)
      voter5 = Factory(:voter, :campaign => campaign, :call_back => true, :voter_list => voter_list2, :last_call_attempt_time => 8.minutes.ago)
      voter6 = Factory(:voter, :campaign => campaign, :call_back => true, :voter_list => voter_list2, :last_call_attempt_time => 1.minutes.ago)
      voter7 = Factory(:voter, :voter_list => voter_list1)
      voter8 = Factory(:voter, :campaign => campaign)
      Voter.just_called_voters_call_back(campaign.id, active_list_ids).should == [voter1, voter2, voter3]
    end

  end

  describe "to be dialed" do
    it "includes voters never called" do
      voter = Factory(:voter, :status => Voter::Status::NOTCALLED)
      Voter.to_be_dialed.should == [voter]
    end

    it "includes voters with a busy signal" do
      voter = Factory(:voter, :status => CallAttempt::Status::BUSY)
      Factory(:call_attempt, :voter => voter, :status => CallAttempt::Status::BUSY)
      Voter.to_be_dialed.should == [voter]
    end

    (CallAttempt::Status::ALL - [CallAttempt::Status::SUCCESS]).each do |status|
      it "includes voters with a status of #{status} " do
        voter = Factory(:voter, :status => status)
        Voter.to_be_dialed.should == [voter]
      end
    end

    it "excludes voters with a status of a successful call" do
      voter = Factory(:voter, :status => CallAttempt::Status::SUCCESS)
      Voter.to_be_dialed.should be_empty
    end

    it "excludes voters with a successful call_attempt" do
      voter = Factory(:voter, :call_back => false, :status => Voter::SUCCESS, :campaign => Factory(:campaign))
      Twilio::Call.stub(:make).and_return({"TwilioResponse" => {"Call" => {"Sid" => "sid"}}})
      Factory(:call_attempt, :voter => voter, :status => CallAttempt::Status::SUCCESS)
      voter.dial.should == false
    end


    it "is ordered by the last_call_attempt_time" do
      v1 = Factory(:voter, :status => CallAttempt::Status::BUSY, :last_call_attempt_time => 2.hours.ago)
      v2 = Factory(:voter, :status => CallAttempt::Status::BUSY, :last_call_attempt_time => 1.hour.ago)
      Voter.to_be_dialed.should == [v1, v2]
    end

    it "prioritizes uncalled voters over called voters" do
      called_voter = Factory(:voter, :status => CallAttempt::Status::BUSY, :last_call_attempt_time => 2.hours.ago)
      uncalled_voter = Factory(:voter, :status => Voter::Status::NOTCALLED)
      Voter.to_be_dialed.should == [uncalled_voter, called_voter]
    end
  end

  describe "voter attributes" do
    let(:voter) { Factory(:voter, :campaign => Factory(:campaign, :account => Factory(:account)), :Phone => '384756923349') }

    it "populates original attributes" do
      voter.apply_attribute('Phone', '0123456789')
      voter.Phone.should == '0123456789'
    end

    it "populates custom attributes" do
      attribute, value = 'Custom', 'foo'
      voter.apply_attribute(attribute, value)
      field = CustomVoterField.find_by_name(attribute)
      field.should_not be_nil
      CustomVoterFieldValue.voter_fields(voter, field).first.value.should == value
    end

    it "returns value of original attributes" do
      attribute, value = 'Phone', '2947832874'
      voter.apply_attribute(attribute, value)
      voter.get_attribute(attribute).should == value
    end

    it "returns value of custom attributes" do
      attribute, value = 'Custom', 'abcde'
      voter.apply_attribute(attribute, value)
      voter.get_attribute(attribute).should == value
    end

    it "fails to update if it fails to validate" do
      original_number = voter.Phone
      attribute, value = 'Phone', '12345'
      voter.apply_attribute(attribute, value).should be_false
      voter.reload.get_attribute(attribute).should == original_number
    end
  end

  it "lists scheduled voters" do
    recent_voter = Factory(:voter, :scheduled_date => 2.minutes.ago, :status => CallAttempt::Status::SCHEDULED, :call_back => true)
    really_old_voter = Factory(:voter, :scheduled_date => 2.hours.ago, :status => CallAttempt::Status::SCHEDULED, :call_back => true)
    recent_but_unscheduled_voter = Factory(:voter, :scheduled_date => 1.minute.ago, :status => nil)
    Voter.scheduled.should == [recent_voter]
  end

  it "provides voter information with custom fields" do
    voter = Factory(:voter, :campaign => Factory(:campaign, :account => Factory(:account)))
    voter_no_custom = Factory(:voter, :campaign => Factory(:campaign, :account => Factory(:account)))
    voter.apply_attribute('foo', 'bar')
    voter.apply_attribute('goo', 'car')
    voter.info.should == {:fields => voter.attributes.reject { |k, v| ["created_at", "updated_at"].include? k }, :custom_fields => {'foo' => 'bar', 'goo' => 'car'}}
    voter_no_custom.info == {:fields => voter_no_custom.attributes.reject { |k, v| ["created_at", "updated_at"].include? k }, :custom_fields => {}}
  end

  it "limits voters when listing them" do
    10.times { Factory(:voter) }
    Voter.limit(5).should have(5).voters
  end

  describe "voter attributes" do
    let(:voter) { Factory(:voter, :campaign => Factory(:campaign, :account=> Factory(:account)), :Phone => '384756923349') }

    it "populates original attributes" do
      voter.apply_attribute('Phone', '0123456789')
      voter.Phone.should == '0123456789'
    end

    it "populates custom attributes" do
      attribute, value = 'Custom', 'foo'
      voter.apply_attribute(attribute, value)
      field = CustomVoterField.find_by_name(attribute)
      field.should_not be_nil
      CustomVoterFieldValue.voter_fields(voter, field).first.value.should == value
    end

    it "returns value of original attributes" do
      attribute, value = 'Phone', '2947832874'
      voter.apply_attribute(attribute, value)
      voter.get_attribute(attribute).should == value
    end

    it "returns value of custom attributes" do
      attribute, value = 'Custom', 'abcde'
      voter.apply_attribute(attribute, value)
      voter.get_attribute(attribute).should == value
    end

  end

  it "excludes specific numbers" do
    unblocked_voter = Factory(:voter, :Phone => "1234567890")
    blocked_voter = Factory(:voter, :Phone => "0123456789")
    Voter.without(['0123456789']).should == [unblocked_voter]
  end

  describe 'blocked?' do
    let(:voter) { Factory(:voter, :account => Factory(:account), :Phone => '1234567890', :campaign => Factory(:campaign)) }

    it "knows when it isn't blocked" do
      voter.should_not be_blocked
    end

    it "knows when it is blocked system-wide" do
      voter.account.blocked_numbers.create(:number => voter.Phone)
      voter.should be_blocked
    end

    it "doesn't care if it blocked for a different campaign" do
      voter.account.blocked_numbers.create(:number => voter.Phone, :campaign => Factory(:campaign))
      voter.should_not be_blocked
    end

    it "knows when it is blocked for its campaign" do
      voter.account.blocked_numbers.create(:number => voter.Phone, :campaign => voter.campaign)
      voter.should be_blocked
    end
  end

  describe 'answers' do
    let(:script) { Factory(:script, :robo => false) }
    let(:campaign) { Factory(:campaign, :script => script) }
    let(:voter) { Factory(:voter, :campaign => campaign)}
    let(:question) { Factory(:question, :script => script) }
    let(:response) { Factory(:possible_response, :question => question) }

    it "captures call responses" do
      response_params = {"voter_id"=>voter.id, "question"=>{question.id=>response.id}, "action"=>"voter_response", "controller"=>"call_attempts", "id"=>"11"}
      voter.capture(response_params)
      voter.result_date.should_not be_nil
      voter.answers.size.should == 1
    end

    it "puts voter back in the dial list if a retry response is detected" do
      another_response = Factory(:possible_response, :question => Factory(:question, :script => script), :retry => true)
      response_params = {"voter_id"=>voter.id, "question"=>{question.id=>response.id, another_response.question.id=>another_response.id}, "action"=>"voter_response", "controller"=>"call_attempts", "id"=>"11"}
      voter.capture(response_params)
      voter.answers.size.should == 2
      voter.reload.status.should == Voter::Status::RETRY
      Voter.to_be_dialed.should == [voter]
    end

    it "overrides old responses with newer ones" do
      question = Factory(:question, :script => script)
      retry_response = Factory(:possible_response, :question => question, :retry => true)
      valid_response = Factory(:possible_response, :question => question)
      response_params = {"voter_id"=>voter.id, "question"=>{response.question.id=>response.id, retry_response.question.id=> retry_response.id}, "action"=>"voter_response", "controller"=>"call_attempts", "id"=>"11"}
      voter.capture(response_params)
      voter.answers.size.should == 2
      voter.reload.status.should == Voter::Status::RETRY
      Voter.to_be_dialed.should == [voter]
      response_params_again = {"voter_id"=>voter.id, "question"=>{response.question.id=>response.id, valid_response.question.id=> valid_response.id}, "action"=>"voter_response", "controller"=>"call_attempts", "id"=>"11"}
      voter.capture(response_params_again)
      voter.reload.answers.size.should == 2
    end

    it "returns all questions unanswered" do
      answered_question = Factory(:question, :script => script)
      Factory(:answer, :voter => voter, :question => answered_question, :possible_response => Factory(:possible_response, :question => answered_question))
      pending_question = Factory(:question, :script => script)
      voter.unanswered_questions.should == [pending_question]
    end
  end

  describe "notes" do
    let(:voter) { Factory(:voter) }
    let(:script) { Factory(:script, :robo => false) }
    let(:note1) { Factory(:note, note: "Question1", script: script) }
    let(:note2) { Factory(:note, note: "Question2", script: script) }

    it "captures call notes" do
      response_params = {"voter_id"=>voter.id, "notes"=>{note1.id=>"tell", note2.id=>"no"}, "action"=>"voter_response", "controller"=>"call_attempts", "id"=>"11"}
      voter.capture(response_params)
      voter.note_responses.size.should == 2
    end

    it "override old note" do
      response_params = {"voter_id"=>voter.id, "notes"=>{note1.id=>"tell"}, "action"=>"voter_response", "controller"=>"call_attempts", "id"=>"11"}
      voter.capture(response_params)
      voter.note_responses.first eq('tell')

      response_params = {"voter_id"=>voter.id, "notes"=>{note1.id=>"say"}, "action"=>"voter_response", "controller"=>"call_attempts", "id"=>"11"}
      voter.capture(response_params)
      voter.note_responses.first eq('say')
    end
  end

  describe "last_call_attempt_before_recycle_rate" do
    it "should return voter if call attempt was before recycle rate hours" do
      campaign = Factory(:campaign)
      voter = Factory(:voter, :campaign => campaign, last_call_attempt_time: 150.minutes.ago)
      Voter.last_call_attempt_before_recycle_rate(2).first.should eq(voter)
    end

    it "should return not voter if call attempt was within recycle rate hours" do
      campaign = Factory(:campaign)
      voter = Factory(:voter, :campaign => campaign, last_call_attempt_time: 110.minutes.ago)
      Voter.last_call_attempt_before_recycle_rate(2).length.should eq(0)
    end

    it "should return  voter if call not attempted " do
      campaign = Factory(:campaign)
      voter = Factory(:voter, :campaign => campaign, last_call_attempt_time: nil)
      Voter.last_call_attempt_before_recycle_rate(2).length.should eq(1)
    end


  end

end
