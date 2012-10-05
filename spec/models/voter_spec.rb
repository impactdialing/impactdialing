require "spec_helper"

describe Voter do
  class Voter
    def dial_predictive
      call_attempt = new_call_attempt(self.campaign.type)
      Twilio.connect(TWILIO_ACCOUNT, TWILIO_AUTH)
      params = {'FallbackUrl' => TWILIO_ERROR, 'StatusCallback' => flow_call_url(call_attempt.call, host:  Settings.twilio_callback_host, port:  Settings.twilio_callback_port, event: 'call_ended'), 'Timeout' => campaign.use_recordings ? "20" : "15"}
      params.merge!({'IfMachine'=> 'Continue'}) if campaign.answering_machine_detect
      response = Twilio::Call.make(campaign.caller_id, self.Phone, flow_call_url(call_attempt.call, host:  Settings.twilio_callback_host, port:  Settings.twilio_callback_port, event:  'incoming_call'), params)
      if response["TwilioResponse"]["RestException"]
        call_attempt.update_attributes(status: CallAttempt::Status::FAILED, wrapup_time: Time.now)
        update_attributes(status: CallAttempt::Status::FAILED)
        Rails.logger.info "[dialer] Exception when attempted to call #{self.Phone} for campaign id:#{self.campaign_id}  Response: #{response["TwilioResponse"]["RestException"].inspect}"
        return
      end
      call_attempt.update_attributes(:sid => response["TwilioResponse"]["Call"]["Sid"])
    end
  end

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

  it "gives remaining voters to count" do
    campaign = Factory(:campaign)
    no_answr_voter = Factory(:voter, :campaign => campaign, :status=> CallAttempt::Status::NOANSWER)
    busy_voter = Factory(:voter, :campaign => campaign, :status=> CallAttempt::Status::BUSY)
    abandon_voter = Factory(:voter, :campaign => campaign, :status=> CallAttempt::Status::ABANDONED)
    schedule_voter = Factory(:voter, :campaign => campaign, :status=> CallAttempt::Status::SCHEDULED, :call_back => true)
    not_called_voter = Factory(:voter, :campaign => campaign, :status=> Voter::Status::NOTCALLED)
    failed_voter = Factory(:voter, :campaign => campaign, :status=> CallAttempt::Status::FAILED, :call_back => true)
    ready_voter = Factory(:voter, :campaign => campaign, :status=> CallAttempt::Status::READY)
    success_voter = Factory(:voter, :campaign => campaign, :status=> CallAttempt::Status::SUCCESS)
    Voter.remaining_voters_for_campaign(campaign).should have(6).items
  end

  it "allows international phone numbers beginning with +" do
    voter = Factory(:voter, :Phone => "+2353546")
    voter.should be_valid
  end

  it "validation fails when phone number not given" do
    voter = Factory.build(:voter, :Phone => nil)
    voter.should_not be_valid
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

  it "returns voters from an enabled list" do
    voter_from_enabled_list = Factory(:voter, :voter_list => Factory(:voter_list, :enabled => true), enabled: true)
    voter_from_disabled_list = Factory(:voter, :voter_list => Factory(:voter_list, :enabled => false), enabled: false)
    Voter.enabled.should == [voter_from_enabled_list]
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

  it "returns voters who have responded within a time range" do
    v1 = Factory(:voter, :result_date => Time.new(2012, 2, 14, 10))
    v2 = Factory(:voter, :result_date => Time.new(2012, 2, 14, 15))
    v3 = Factory(:voter, :result_date => Time.new(2012, 2, 14, 20))
    Voter.answered_within_timespan(Time.new(2012, 2, 14, 10), Time.new(2012, 2, 14, 12)).should == [v1]
    Voter.answered_within_timespan(Time.new(2012, 2, 14, 12), Time.new(2012, 2, 14, 23, 59, 59)).should == [v2, v3]
    Voter.answered_within_timespan(Time.new(2012, 2, 14, 0), Time.new(2012, 2, 14, 9, 59, 59)).should == []
  end


  describe "voter fields" do
    let(:account) { Factory(:account) }
    let(:voter) { Factory(:voter, :account => account) }
    let(:field1) { Factory(:custom_voter_field, :name => "field1", :account => account) }
    let(:field2) { Factory(:custom_voter_field, :name => "field2", :account => account) }
    let(:field3) { Factory(:custom_voter_field, :name => "field3", :account => account) }

    it "lists voters custom fields with selected field names" do
      value1 = Factory(:custom_voter_field_value, :voter => voter, :custom_voter_field => field1, :value => "value1")
      value2 = Factory(:custom_voter_field_value, :voter => voter, :custom_voter_field => field2, :value => "value2")
      voter.selected_custom_fields([field1.name, field2.name]).should == [value1.value, value2.value]
      voter.selected_custom_fields([field2.name, field1.name]).should == [value2.value, value1.value]
      voter.selected_custom_fields(nil).should == []
    end

    it "lists voters custom fields with selected field names" do
      value2 = Factory(:custom_voter_field_value, :voter => voter, :custom_voter_field => field2, :value => "value2")
      voter.selected_custom_fields([field1.name, field2.name, field3.name]).should == [nil, value2.value, nil]
    end

    it "lists selected voter fields" do
      phone, custom_id, firstname = "39045098753", "24566", "first"
      voter.update_attributes(:Phone => phone, :CustomID => custom_id, :FirstName => firstname)
      voter.selected_fields(["Phone", "FirstName", "LastName"]).should == [phone, firstname, nil]
      voter.selected_fields(["Phone", "LastName", "FirstName"]).should == [phone, nil, firstname]
    end

    it "selects phone number if there are no selected fields" do
      phone, custom_id, firstname = "39045098753", "24566", "first"
      voter.update_attributes(:Phone => phone, :CustomID => custom_id, :FirstName => firstname)
      voter.selected_fields.should == [phone]
    end

  end

  describe "predictive dialing" do
    let(:campaign) { Factory(:predictive, answering_machine_detect: true) }
    let(:voter) { Factory(:voter, :campaign => campaign) }
    let(:client) { mock(:client).tap { |client| Twilio::REST::Client.stub(:new).and_return(client) } }

    context 'making calls' do
      before(:each) do
        Twilio::Call.should_receive(:make).with(anything, voter.Phone, anything, {"FallbackUrl"=>"blah", 'StatusCallback'=> anything, 'IfMachine' => 'Continue', 'Timeout' => anything}).and_return({"TwilioResponse" => {"Call" => {"Sid" => "sid"}}})
      end

      it "is dialed" do
        caller_session = Factory(:caller_session, :available_for_call => true, :on_call => true, campaign: campaign)
        campaign.stub(:time_period_exceed?).and_return(false)
        voter.dial_predictive
        call_attempt = CallAttempt.first
        call_attempt.sid.should == "sid"
        call_attempt.status.should == CallAttempt::Status::RINGING
      end

      it "updates voter attributes" do
        time_now = Time.now
        Time.stub!(:now).and_return(time_now)
        caller_session = Factory(:caller_session, :available_for_call => true, :on_call => true, campaign: campaign)
        campaign.stub(:time_period_exceed?).and_return(false)
        voter.dial_predictive
        call_attempt = voter.call_attempts.last
        voter.last_call_attempt.should == call_attempt
        DateTime.parse(voter.last_call_attempt_time.to_s).should == DateTime.parse(time_now.utc.to_s)
      end

      it "updates the call_attempts campaign" do
        caller_session = Factory(:caller_session, :available_for_call => true, :on_call => true, campaign: campaign)
        campaign.stub(:time_period_exceed?).and_return(false)
        voter.dial_predictive
        call_attempt = voter.call_attempts.last
        call_attempt.campaign.should == voter.campaign
      end
    end

    it "dials the voter and hangs up on answering machine when not using recordings" do
      Twilio::Call.should_receive(:make).with(anything, voter.Phone, anything, {"FallbackUrl"=>"blah", 'StatusCallback'=> anything, 'IfMachine' => 'Continue', 'Timeout' => anything}).and_return({"TwilioResponse" => {"Call" => {"Sid" => "sid"}}})
      campaign.stub(:time_period_exceed?).and_return(false)
      voter.dial_predictive
    end

    it "dials the voter and continues on answering machine when using recordings" do
      Twilio::Call.should_receive(:make).with(anything, voter.Phone, anything, {"FallbackUrl"=>"blah", 'StatusCallback'=> anything, 'IfMachine' => 'Continue', 'Timeout' => anything}).and_return({"TwilioResponse" => {"Call" => {"Sid" => "sid"}}})
      voter.campaign = campaign
      campaign.stub(:time_period_exceed?).and_return(false)
      voter.dial_predictive
    end

    it "dials the voter without IFMachine if AMD detection turned off" do
      campaign1 = Factory(:campaign, :type => 'Predictive', answering_machine_detect: false)
      Twilio::Call.should_receive(:make).with(anything, voter.Phone, anything, {"FallbackUrl"=>"blah", 'StatusCallback'=> anything, 'Timeout' => anything}).and_return({"TwilioResponse" => {"Call" => {"Sid" => "sid"}}})
      voter.campaign = campaign1
      campaign1.stub(:time_period_exceed?).and_return(false)
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

    (CallAttempt::Status::ALL - [CallAttempt::Status::INPROGRESS, CallAttempt::Status::RINGING, CallAttempt::Status::READY, CallAttempt::Status::SUCCESS, CallAttempt::Status::FAILED]).each do |status|
      it "includes voters with a status of #{status} " do
        voter = Factory(:voter, :status => status)
        Voter.to_be_dialed.should == [voter]
      end
    end

    it "excludes voters with a status of a successful call" do
      voter = Factory(:voter, :status => CallAttempt::Status::SUCCESS)
      Voter.to_be_dialed.should be_empty
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


  it "lists scheduled voters" do
    recent_voter = Factory(:voter, :scheduled_date => 2.minutes.ago, :status => CallAttempt::Status::SCHEDULED, :call_back => true)
    really_old_voter = Factory(:voter, :scheduled_date => 2.hours.ago, :status => CallAttempt::Status::SCHEDULED, :call_back => true)
    recent_but_unscheduled_voter = Factory(:voter, :scheduled_date => 1.minute.ago, :status => nil)
    Voter.scheduled.should == [recent_voter]
  end


  it "limits voters when listing them" do
    10.times { Factory(:voter) }
    Voter.limit(5).should have(5).voters
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
    let(:script) { Factory(:script) }
    let(:campaign) { Factory(:predictive, :script => script) }
    let(:voter) { Factory(:voter, :campaign => campaign, :caller_session => Factory(:caller_session, :caller => Factory(:caller))) }
    let(:question) { Factory(:question, :script => script) }
    let(:response) { Factory(:possible_response, :question => question) }
    let(:call_attempt) { Factory(:call_attempt, :caller => Factory(:caller)) }

    it "captures call responses" do
      voter.persist_answers("{\"#{question.id}\":\"#{response.id}\"}",call_attempt)
      voter.answers.size.should == 1
    end

    it "puts voter back in the dial list if a retry response is detected" do
      another_response = Factory(:possible_response, :question => Factory(:question, :script => script), :retry => true)
      voter.persist_answers("{\"#{question.id}\":\"#{response.id}\",\"#{another_response.question.id}\":\"#{another_response.id}\" }",call_attempt)
      voter.answers.size.should == 2
      voter.reload.status.should == Voter::Status::RETRY
      Voter.to_be_dialed.should == [voter]
    end

    it "does not override old responses with newer ones" do
      question = Factory(:question, :script => script)
      retry_response = Factory(:possible_response, :question => question, :retry => true)
      valid_response = Factory(:possible_response, :question => question)
      voter.persist_answers("{\"#{response.question.id}\":\"#{response.id}\",\"#{retry_response.question.id}\":\"#{retry_response.id}\" }",call_attempt)
      voter.answers.size.should == 2
      voter.reload.status.should == Voter::Status::RETRY
      Voter.to_be_dialed.should == [voter]
      voter.persist_answers("{\"#{response.question.id}\":\"#{response.id}\",\"#{valid_response.question.id}\":\"#{valid_response.id}\" }",call_attempt)
      voter.reload.answers.size.should == 4
    end

    it "returns all questions unanswered" do
      answered_question = Factory(:question, :script => script)
      Factory(:answer, :voter => voter, :question => answered_question, :possible_response => Factory(:possible_response, :question => answered_question))
      pending_question = Factory(:question, :script => script)
      voter.unanswered_questions.should == [pending_question]
    end

    it "associates the caller with the answer" do
      caller = Factory(:caller)
      session = Factory(:caller_session, :caller => caller)
      voter = Factory(:voter, :campaign => campaign, :last_call_attempt => Factory(:call_attempt, :caller_session => session))
      Factory(:possible_response, :question => question, :keypad => 1, :value => "response1")
      voter.answer(question, "1", session).caller_id.should == caller.id
    end

    describe "phones only" do
      let(:script) { Factory(:script) }
      let(:campaign) { Factory(:predictive, :script => script) }
      let(:voter) { Factory(:voter, :campaign => campaign, :last_call_attempt => Factory(:call_attempt, :caller_session => Factory(:caller_session))) }
      let(:question) { Factory(:question, :script => script) }
      let(:session) { Factory(:caller_session, :caller => Factory(:caller)) }

      it "captures a voter response" do
        Factory(:possible_response, :question => question, :keypad => 1, :value => "response1")
        voter.answer(question, "1", session).should == voter.answers.first
        voter.answers.size.should == 1
      end

      it "rejects an incorrect a voter response" do
        Factory(:possible_response, :question => question, :keypad => 1, :value => "response1")
        voter.answer(question, "2", session).should == nil
        voter.answers.size.should == 0
      end

      it "recaptures a voter response" do
        voter.answer(question, "1", session)
        Factory(:possible_response, :question => question, :keypad => 1, :value => "response1")
        Factory(:possible_response, :question => question, :keypad => 2, :value => "response2")
        voter.answer(question, "2", session).should == voter.answers.first
        voter.answers.size.should == 1
      end

    end
  end

  describe "notes" do

    let(:script) { Factory(:script) }
    let(:note1) { Factory(:note, note: "Question1", script: script) }
    let(:note2) { Factory(:note, note: "Question2", script: script) }
    let(:call_attempt) { Factory(:call_attempt, :caller => Factory(:caller)) }
    let(:voter) { Factory(:voter, last_call_attempt: call_attempt) }

    it "captures call notes" do
      voter.persist_notes("{\"#{note1.id}\":\"tell\",\"#{note2.id}\":\"no\"}", call_attempt)
      voter.note_responses.size.should == 2
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

  describe "skip voter" do
    it "should skip voter but adding skipped_time" do
      campaign = Factory(:campaign)
      voter = Factory(:voter, :campaign => campaign)
      voter.skip
      voter.skipped_time.should_not be_nil
    end
  end

  describe "avialable_to_be_retried" do

    it "should not consider voters who have not been dialed" do
      campaign = Factory(:campaign)
      voter = Factory(:voter, :campaign => campaign, last_call_attempt_time: nil)
      Voter.avialable_to_be_retried(campaign.recycle_rate).should eq([])
    end

    it "should not consider voters who last call attempt is within recycle rate" do
      campaign = Factory(:campaign, recycle_rate: 4)
      voter = Factory(:voter, :campaign => campaign, last_call_attempt_time: Time.now - 2.hours)
      Voter.avialable_to_be_retried(campaign.recycle_rate).should eq([])
    end

    it "should  consider voters who last call attempt is not within recycle rate for hangup status" do
      campaign = Factory(:campaign, recycle_rate: 1)
      voter = Factory(:voter, :campaign => campaign, last_call_attempt_time: Time.now - 2.hours, status: CallAttempt::Status::HANGUP)
      Voter.avialable_to_be_retried(campaign.recycle_rate).size.should eq(1)
    end

    it "should not  consider voters who last call attempt is not within recycle rate for success status" do
      campaign = Factory(:campaign, recycle_rate: 1)
      voter = Factory(:voter, :campaign => campaign, last_call_attempt_time: Time.now - 2.hours, status: CallAttempt::Status::SUCCESS)
      Voter.avialable_to_be_retried(campaign.recycle_rate).should eq([])
    end

  end

  describe "not_avialable_to_be_retried" do

    it "should not consider voters who have not been dialed" do
      campaign = Factory(:campaign)
      voter = Factory(:voter, :campaign => campaign, last_call_attempt_time: nil)
      Voter.not_avialable_to_be_retried(campaign.recycle_rate).should eq([])
    end

    it "should not consider voters who last call attempt is not within recycle rate" do
      campaign = Factory(:campaign, recycle_rate: 1)
      voter = Factory(:voter, :campaign => campaign, last_call_attempt_time: Time.now - 2.hours)
      Voter.not_avialable_to_be_retried(campaign.recycle_rate).should eq([])
    end

    it "should  not consider voters who last call attempt is  within recycle rate for hangup status" do
      campaign = Factory(:campaign, recycle_rate: 1)
      voter = Factory(:voter, :campaign => campaign, last_call_attempt_time: Time.now - 2.hours, status: CallAttempt::Status::HANGUP)
      Voter.not_avialable_to_be_retried(campaign.recycle_rate).should eq([])
    end

    it "should   consider voters who last call attempt is not within recycle rate for hangup status" do
      campaign = Factory(:campaign, recycle_rate: 3)
      voter = Factory(:voter, :campaign => campaign, last_call_attempt_time: Time.now - 2.hours, status: CallAttempt::Status::HANGUP)
      Voter.not_avialable_to_be_retried(campaign.recycle_rate).should eq([voter])
    end

  end
end
