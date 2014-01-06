require "spec_helper"
require 'fiber'
describe Voter do
  class Voter
    def dial_predictive
      call_attempt = new_call_attempt(self.campaign.type)
      Twilio.connect(TWILIO_ACCOUNT, TWILIO_AUTH)
      params = {'FallbackUrl' => TWILIO_ERROR, 'StatusCallback' => flow_call_url(call_attempt.call, host:  Settings.twilio_callback_host, port:  Settings.twilio_callback_port, event: 'call_ended'), 'Timeout' => campaign.use_recordings ? "20" : "15"}
      params.merge!({'IfMachine'=> 'Continue'}) if campaign.answering_machine_detect
      response = Twilio::Call.make(campaign.caller_id, self.phone, flow_call_url(call_attempt.call, host:  Settings.twilio_callback_host, port:  Settings.twilio_callback_port, event:  'incoming_call'), params)
      if response["TwilioResponse"]["RestException"]
        call_attempt.update_attributes(status: CallAttempt::Status::FAILED, wrapup_time: Time.now)
        update_attributes(status: CallAttempt::Status::FAILED)
        Rails.logger.info "[dialer] Exception when attempted to call #{self.phone} for campaign id:#{self.campaign_id}  Response: #{response["TwilioResponse"]["RestException"].inspect}"
        return
      end
      call_attempt.update_attributes(:sid => response["TwilioResponse"]["Call"]["Sid"])
    end
  end

  include Rails.application.routes.url_helpers

  it "can share the same number" do
    voter1 = create(:voter, :phone => '92345623434')
    voter2 = create(:voter, :phone => '92345623434')
    Voter.all.should include(voter1)
    Voter.all.should include(voter2)
  end

  it "should list existing entries in a campaign having the given phone number" do
    lambda {
      create(:voter, :phone => '0123456789', :campaign_id => 99)
    }.should change {
      Voter.existing_phone_in_campaign('0123456789', 99).count
    }.by(1)
  end

  it "gives remaining voters to count" do
    campaign = create(:campaign)
    no_answr_voter = create(:voter, :campaign => campaign, :status=> CallAttempt::Status::NOANSWER)
    busy_voter = create(:voter, :campaign => campaign, :status=> CallAttempt::Status::BUSY)
    abandon_voter = create(:voter, :campaign => campaign, :status=> CallAttempt::Status::ABANDONED)
    schedule_voter = create(:voter, :campaign => campaign, :status=> CallAttempt::Status::SCHEDULED, :call_back => true)
    not_called_voter = create(:voter, :campaign => campaign, :status=> Voter::Status::NOTCALLED)
    failed_voter = create(:voter, :campaign => campaign, :status=> CallAttempt::Status::FAILED, :call_back => true)
    ready_voter = create(:voter, :campaign => campaign, :status=> CallAttempt::Status::READY)
    success_voter = create(:voter, :campaign => campaign, :status=> CallAttempt::Status::SUCCESS)
    Voter.remaining_voters_for_campaign(campaign).should have(6).items
  end

  it "allows international phone numbers beginning with +" do
    voter = create(:voter, :phone => "+2353546")
    voter.should be_valid
  end

  it "validation fails when phone number not given" do
    voter = build(:voter, :phone => nil)
    voter.should_not be_valid
  end

  it "lists voters not called" do
    voter1 = create(:voter, :campaign => create(:campaign), :status=> Voter::Status::NOTCALLED)
    voter2 = create(:voter, :campaign => create(:campaign), :status=> Voter::Status::NOTCALLED)
    create(:voter, :campaign => create(:campaign), :status=> "Random")
    Voter.by_status(Voter::Status::NOTCALLED).should include(voter1)
    Voter.by_status(Voter::Status::NOTCALLED).should include(voter2)
  end

  it "returns only active voters" do
    active_voter = create(:voter, :active => true)
    inactive_voter = create(:voter, :active => false)
    Voter.active.should include(active_voter)
  end

  it "returns voters from an enabled list" do
    voter_from_enabled_list = create(:voter, :voter_list => create(:voter_list, :enabled => true), enabled: true)
    voter_from_disabled_list = create(:voter, :voter_list => create(:voter_list, :enabled => false), enabled: false)
    Voter.enabled.should include(voter_from_enabled_list)
  end

  it "returns voters that have responded" do
    create(:voter)
    3.times { create(:voter, :result_date => Time.now) }
    Voter.answered.size.should == 3
  end

  it "returns voters that have responded within a date range" do
    create(:voter)
    v1 = create(:voter, :result_date => DateTime.now)
    v2 = create(:voter, :result_date => 1.day.ago)
    v3 = create(:voter, :result_date => 2.days.ago)
    Voter.answered_within(2.days.ago, 0.days.ago).should == [v1, v2, v3]
    Voter.answered_within(2.days.ago, 1.day.ago).should == [v2, v3]
    Voter.answered_within(1.days.ago, 1.days.ago).should == [v2]
  end

  it "returns voters who have responded within a time range" do
    v1 = create(:voter, :result_date => Time.new(2012, 2, 14, 10))
    v2 = create(:voter, :result_date => Time.new(2012, 2, 14, 15))
    v3 = create(:voter, :result_date => Time.new(2012, 2, 14, 20))
    Voter.answered_within_timespan(Time.new(2012, 2, 14, 10), Time.new(2012, 2, 14, 12)).should == [v1]
    Voter.answered_within_timespan(Time.new(2012, 2, 14, 12), Time.new(2012, 2, 14, 23, 59, 59)).should == [v2, v3]
    Voter.answered_within_timespan(Time.new(2012, 2, 14, 0), Time.new(2012, 2, 14, 9, 59, 59)).should == []
  end

  describe 'calculating number of voters left to dial in given voter list' do
    def setup_voters(n=10, voter_opts={})
      vopt = voter_opts.merge({
        enabled: true
      })
      create_list(:voter, n, vopt)
      Voter.count.should eq n
      @voters = Voter.all
      last_call_time = 20.hours.ago
    end

    let(:voter_list){ create(:voter_list) }

    before do
      setup_voters(10, {voter_list_id: voter_list.id})
      @query = Voter.remaining_voters_for_voter_list(voter_list)
    end

    context 'no voters in the list have been called' do
      it 'returns the size of the voter list' do
        @query.count.should eq 10
      end
    end

    context '3 voters in the list were called but the call failed' do
      before do
        3.times do |i|
          @voters[i].update_attribute(:status, 'Call failed')
        end
      end
      it 'returns the size of the voter list minus 3' do
        @query.count.should eq 7
      end
    end

    context '3 voters in the list were called and scheduled for call backs' do
      it 'returns the size of the voter list minus 3'
      it 'includes the scheduled voters in the count when it is near their scheduled date'
    end
  end

  describe "Dialing" do
    let(:campaign) { create(:robo) }
    let(:voter) { create(:voter, :campaign => campaign) }

    it "records users to call back" do
      voter1 = create(:voter)
      Voter.to_callback.should == []
      voter2 = create(:voter, :call_back =>true)
      Voter.to_callback.should == [voter2]
    end
  end


  describe "predictive dialing" do
    let(:campaign) { create(:predictive, answering_machine_detect: true) }
    let(:voter) { create(:voter, :campaign => campaign) }
    let(:client) { double(:client).tap { |client| Twilio::REST::Client.stub(:new).and_return(client) } }

    it "checks, whether voter is called or not" do
      voter1 = create(:voter, :status => "not called")
      voter2 = create(:voter, :status => "success")
      voter1.not_yet_called?("not called").should be_true
      voter2.not_yet_called?("not called").should be_false
    end

    it "checks, call attemp made before 3 hours or not" do
      voter1 = create(:voter, :last_call_attempt_time => 4.hours.ago, :call_back => true)
      voter2 = create(:voter, :last_call_attempt_time => 2.hours.ago, :call_back => true)
      voter1.call_attempted_before?(3.hours).should be_true
      voter2.call_attempted_before?(3.hours).should be_false
      voter2.call_attempted_before?(10.minutes).should be_true
    end

    it "returns all the voters to be call" do
      campaign = create(:campaign)
      voter_list1 = create(:voter_list)
      voter_list2 = create(:voter_list)
      active_list_ids = [voter_list1.id, voter_list2.id]
      status = "not called"
      voter1 = create(:voter, :campaign => campaign, :voter_list => voter_list1)
      voter2 = create(:voter, :campaign => campaign, :voter_list => voter_list1, last_call_attempt_time: 2.hours.ago, status: CallAttempt::Status::VOICEMAIL)
      voter3 = create(:voter, :campaign => campaign, :voter_list => voter_list2)
      voter4 = create(:voter, :voter_list => voter_list1)
      voter5 = create(:voter, :campaign => campaign)
      Voter.to_be_called(campaign.id, active_list_ids, status, 3).length.should == 2
    end

    it "return voters, to whoom called just now, but not replied " do
      campaign = create(:campaign)
      voter_list1 = create(:voter_list)
      voter_list2 = create(:voter_list)
      active_list_ids = [voter_list1.id, voter_list2.id]
      status = "not called"
      voter1 = create(:voter, :campaign => campaign, :call_back => true, :voter_list => voter_list1, :last_call_attempt_time => 2.hours.ago)
      voter2 = create(:voter, :campaign => campaign, :call_back => true, :voter_list => voter_list2, :last_call_attempt_time => 1.hours.ago)
      voter3 = create(:voter, :campaign => campaign, :call_back => true, :voter_list => voter_list2, :last_call_attempt_time => 30.minutes.ago)
      voter4 = create(:voter, :campaign => campaign, :call_back => false, :voter_list => voter_list2, :last_call_attempt_time => 50.minutes.ago)
      voter5 = create(:voter, :campaign => campaign, :call_back => true, :voter_list => voter_list2, :last_call_attempt_time => 8.minutes.ago)
      voter6 = create(:voter, :campaign => campaign, :call_back => true, :voter_list => voter_list2, :last_call_attempt_time => 1.minutes.ago)
      voter7 = create(:voter, :voter_list => voter_list1)
      voter8 = create(:voter, :campaign => campaign)
      Voter.just_called_voters_call_back(campaign.id, active_list_ids).should == [voter1, voter2, voter3]
    end

  end

  describe "to be dialed" do
    it "includes voters never called" do
      voter = create(:voter, :status => Voter::Status::NOTCALLED)
      Voter.to_be_dialed.should include(voter)
    end

    it "includes voters with a busy signal" do
      voter = create(:voter, :status => CallAttempt::Status::BUSY)
      create(:call_attempt, :voter => voter, :status => CallAttempt::Status::BUSY)
      Voter.to_be_dialed.should include(voter)
    end

    (CallAttempt::Status::ALL - [CallAttempt::Status::INPROGRESS, CallAttempt::Status::RINGING, CallAttempt::Status::READY, CallAttempt::Status::SUCCESS, CallAttempt::Status::FAILED]).each do |status|
      it "includes voters with a status of #{status} " do
        voter = create(:voter, :status => status)
        Voter.to_be_dialed.should include(voter)
      end
    end

    it "excludes voters with a status of a successful call" do
      voter = create(:voter, :status => CallAttempt::Status::SUCCESS)
      Voter.to_be_dialed.should_not include(voter)
    end

    it "is ordered by the last_call_attempt_time" do
      v1 = create(:voter, :status => CallAttempt::Status::BUSY, :last_call_attempt_time => 2.hours.ago)
      v2 = create(:voter, :status => CallAttempt::Status::BUSY, :last_call_attempt_time => 1.hour.ago)
      Voter.to_be_dialed.should include(v1)
      Voter.to_be_dialed.should include(v2)
    end

    it "prioritizes uncalled voters over called voters" do
      called_voter = create(:voter, :status => CallAttempt::Status::BUSY, :last_call_attempt_time => 2.hours.ago)
      uncalled_voter = create(:voter, :status => Voter::Status::NOTCALLED)
      Voter.to_be_dialed.should include(uncalled_voter)
      Voter.to_be_dialed.should include(called_voter)
    end
  end


  it "lists scheduled voters" do
    recent_voter = create(:voter, :scheduled_date => 2.minutes.ago, :status => CallAttempt::Status::SCHEDULED, :call_back => true)
    really_old_voter = create(:voter, :scheduled_date => 2.hours.ago, :status => CallAttempt::Status::SCHEDULED, :call_back => true)
    recent_but_unscheduled_voter = create(:voter, :scheduled_date => 1.minute.ago, :status => nil)
    Voter.scheduled.should == [recent_voter]
  end


  it "limits voters when listing them" do
    10.times { create(:voter) }
    Voter.limit(5).should have(5).voters
  end


  it "excludes specific numbers" do
    unblocked_voter = create(:voter, :phone => "1234567890")
    blocked_voter = create(:voter, :phone => "0123456789")
    Voter.without(['0123456789']).should include(unblocked_voter)
  end

  describe 'blocked?' do
    let(:voter) { create(:voter, :account => create(:account), :phone => '1234567890', :campaign => create(:campaign)) }

    it "knows when it isn't blocked" do
      voter.should_not be_blocked
    end

    it "knows when it is blocked system-wide" do
      voter.account.blocked_numbers.create(:number => voter.phone)
      voter.should be_blocked
    end

    it "doesn't care if it blocked for a different campaign" do
      voter.account.blocked_numbers.create(:number => voter.phone, :campaign => create(:campaign))
      voter.should_not be_blocked
    end

    it "knows when it is blocked for its campaign" do
      voter.account.blocked_numbers.create(:number => voter.phone, :campaign => voter.campaign)
      voter.should be_blocked
    end
  end

  describe 'answers' do
    let(:script) { create(:script) }
    let(:campaign) { create(:predictive, :script => script) }
    let(:voter) { create(:voter, :campaign => campaign, :caller_session => create(:caller_session, :caller => create(:caller))) }
    let(:question) { create(:question, :script => script) }
    let(:response) { create(:possible_response, :question => question) }
    let(:call_attempt) { create(:call_attempt, :caller => create(:caller)) }

    it "captures call responses" do
      voter.persist_answers("{\"#{question.id}\":\"#{response.id}\"}",call_attempt)
      voter.answers.size.should == 1
    end

    it "puts voter back in the dial list if a retry response is detected" do
      another_response = create(:possible_response, :question => create(:question, :script => script), :retry => true)
      voter.persist_answers("{\"#{question.id}\":\"#{response.id}\",\"#{another_response.question.id}\":\"#{another_response.id}\" }",call_attempt)
      voter.answers.size.should == 2
      voter.reload.status.should == Voter::Status::RETRY
      Voter.to_be_dialed.should include(voter)
    end

    it "does not override old responses with newer ones" do
      question = create(:question, :script => script)
      retry_response = create(:possible_response, :question => question, :retry => true)
      valid_response = create(:possible_response, :question => question)
      voter.persist_answers("{\"#{response.question.id}\":\"#{response.id}\",\"#{retry_response.question.id}\":\"#{retry_response.id}\" }",call_attempt)
      voter.answers.size.should == 2
      voter.reload.status.should == Voter::Status::RETRY
      Voter.to_be_dialed.should include(voter)
      voter.persist_answers("{\"#{response.question.id}\":\"#{response.id}\",\"#{valid_response.question.id}\":\"#{valid_response.id}\" }",call_attempt)
      voter.reload.answers.size.should == 4
    end

    it "returns all questions unanswered" do
      answered_question = create(:question, :script => script)
      create(:answer, :voter => voter, :question => answered_question, :possible_response => create(:possible_response, :question => answered_question))
      pending_question = create(:question, :script => script)
      voter.unanswered_questions.should == [pending_question]
    end

    it "associates the caller with the answer" do
      caller = create(:caller)
      session = create(:caller_session, :caller => caller)
      voter = create(:voter, :campaign => campaign, :last_call_attempt => create(:call_attempt, :caller_session => session))
      create(:possible_response, :question => question, :keypad => 1, :value => "response1")
      voter.answer(question, "1", session).caller_id.should == caller.id
    end

    describe "phones only" do
      let(:script) { create(:script) }
      let(:campaign) { create(:predictive, :script => script) }
      let(:voter) { create(:voter, :campaign => campaign, :last_call_attempt => create(:call_attempt, :caller_session => create(:caller_session))) }
      let(:question) { create(:question, :script => script) }
      let(:session) { create(:caller_session, :caller => create(:caller)) }

      it "captures a voter response" do
        create(:possible_response, :question => question, :keypad => 1, :value => "response1")
        answer = voter.answer(question, "1", session)
        answer.question_id.should eq(question.id)
      end

      it "rejects an incorrect a voter response" do
        create(:possible_response, :question => question, :keypad => 1, :value => "response1")
        voter.answer(question, "2", session).should == nil
        voter.answers.size.should == 0
      end

      it "recaptures a voter response" do
        voter.answer(question, "1", session)
        create(:possible_response, :question => question, :keypad => 1, :value => "response1")
        create(:possible_response, :question => question, :keypad => 2, :value => "response2")
        answer = voter.answer(question, "2", session)
        answer.question_id.should eq(question.id)
      end

    end
  end

  describe "notes" do

    let(:script) { create(:script) }
    let(:note1) { create(:note, note: "Question1", script: script) }
    let(:note2) { create(:note, note: "Question2", script: script) }
    let(:call_attempt) { create(:call_attempt, :caller => create(:caller)) }
    let(:voter) { create(:voter, last_call_attempt: call_attempt) }

    it "captures call notes" do
      voter.persist_notes("{\"#{note1.id}\":\"tell\",\"#{note2.id}\":\"no\"}", call_attempt)
      voter.note_responses.size.should == 2
    end

  end

  describe "last_call_attempt_before_recycle_rate" do
    it "should return voter if call attempt was before recycle rate hours" do
      campaign = create(:campaign)
      voter = create(:voter, :campaign => campaign, last_call_attempt_time: 150.minutes.ago)
      Voter.last_call_attempt_before_recycle_rate(2).should include(voter)
    end

    it "should return not voter if call attempt was within recycle rate hours" do
      campaign = create(:campaign)
      voter = create(:voter, :campaign => campaign, last_call_attempt_time: 110.minutes.ago)
      Voter.last_call_attempt_before_recycle_rate(2).should_not include(voter)
    end

    it "should return  voter if call not attempted " do
      campaign = create(:campaign)
      voter = create(:voter, :campaign => campaign, last_call_attempt_time: nil)
      Voter.last_call_attempt_before_recycle_rate(2).should include(voter)
    end


  end

  describe "skip voter" do
    it "should skip voter but adding skipped_time" do
      campaign = create(:campaign)
      voter = create(:voter, :campaign => campaign)
      voter.skip
      voter.skipped_time.should_not be_nil
    end
  end

  describe "avialable_to_be_retried" do

    it "should not consider voters who have not been dialed" do
      campaign = create(:campaign)
      voter = create(:voter, :campaign => campaign, last_call_attempt_time: nil)
      Voter.avialable_to_be_retried(campaign.recycle_rate).should eq([])
    end

    it "should not consider voters who last call attempt is within recycle rate" do
      campaign = create(:campaign, recycle_rate: 4)
      voter = create(:voter, :campaign => campaign, last_call_attempt_time: Time.now - 2.hours)
      Voter.avialable_to_be_retried(campaign.recycle_rate).should eq([])
    end

    it "should  consider voters who last call attempt is not within recycle rate for hangup status" do
      campaign = create(:campaign, recycle_rate: 1)
      voter = create(:voter, :campaign => campaign, last_call_attempt_time: Time.now - 2.hours, status: CallAttempt::Status::HANGUP)
      Voter.avialable_to_be_retried(campaign.recycle_rate).should include(voter)
    end

    it "should not  consider voters who last call attempt is not within recycle rate for success status" do
      campaign = create(:campaign, recycle_rate: 1)
      voter = create(:voter, :campaign => campaign, last_call_attempt_time: Time.now - 2.hours, status: CallAttempt::Status::SUCCESS)
      Voter.avialable_to_be_retried(campaign.recycle_rate).should_not include(voter)
    end

  end

  describe "not_avialable_to_be_retried" do

    it "should not consider voters who have not been dialed" do
      campaign = create(:campaign)
      voter = create(:voter, :campaign => campaign, last_call_attempt_time: nil)
      Voter.not_avialable_to_be_retried(campaign.recycle_rate).should eq([])
    end

    it "should not consider voters who last call attempt is not within recycle rate" do
      campaign = create(:campaign, recycle_rate: 1)
      voter = create(:voter, :campaign => campaign, last_call_attempt_time: Time.now - 2.hours)
      Voter.not_avialable_to_be_retried(campaign.recycle_rate).should eq([])
    end

    it "should  not consider voters who last call attempt is  within recycle rate for hangup status" do
      campaign = create(:campaign, recycle_rate: 1)
      voter = create(:voter, :campaign => campaign, last_call_attempt_time: Time.now - 2.hours, status: CallAttempt::Status::HANGUP)
      Voter.not_avialable_to_be_retried(campaign.recycle_rate).should eq([])
    end

    it "should   consider voters who last call attempt is not within recycle rate for hangup status" do
      campaign = create(:campaign, recycle_rate: 3)
      voter = create(:voter, :campaign => campaign, last_call_attempt_time: Time.now - 2.hours, status: CallAttempt::Status::HANGUP)
      Voter.not_avialable_to_be_retried(campaign.recycle_rate).should eq([voter])
    end
  end

  describe '.next_in_priority_or_scheduled_queues(blocked_numbers)' do
    let(:campaign){ create(:campaign) }

    it 'loads voters w/ priority=1 and status=Voter::Status::NOTCALLED' do
      expected = [create(:voter, campaign: campaign, status: Voter::Status::NOTCALLED, priority: true)]
      create(:voter, campaign: campaign, status: nil, priority: true)
      create(:voter, campaign: campaign, status: Voter::Status::RETRY, priority: true)
      actual = Voter.next_in_priority_or_scheduled_queues([])
      actual.all.should eq expected
    end

    it 'OR voters scheduled to be called back in the last or next 10 minutes' do
      expected = [
        create(:voter, campaign: campaign, status: CallAttempt::Status::SCHEDULED, scheduled_date: 5.minutes.ago),
        create(:voter, campaign: campaign, status: CallAttempt::Status::SCHEDULED, scheduled_date: 5.minutes.from_now)
      ]
      create(:voter, campaign: campaign, status: CallAttempt::Status::SCHEDULED, scheduled_date: 20.minutes.ago)
      create(:voter, campaign: campaign, status: CallAttempt::Status::SCHEDULED, scheduled_date: 20.minutes.from_now)
      actual = Voter.next_in_priority_or_scheduled_queues([])
      actual.all.should eq expected
    end

    it 'excludes voters w/ phone numbers in the list of blocked numbers' do
      blocked = ['1234567890', '0987654321']
      expected = [
        create(:voter, {
          campaign: campaign,
          status: Voter::Status::NOTCALLED,
          priority: true
        })
      ]
      create(:voter, {
        campaign: campaign,
        status: Voter::Status::NOTCALLED,
        phone: blocked.first
      })
      create(:voter, {
        campaign: campaign,
        status: Voter::Status::NOTCALLED,
        phone: blocked.second
      })
      actual = Voter.next_in_priority_or_scheduled_queues(blocked).all
      actual.should eq expected
    end
  end

  describe '.next_recycled_voter(recycle_rate, blocked_numbers, current_voter_id)' do
    def setup_voters(campaign_opts={}, voter_opts={})
      @campaign = create(:preview, campaign_opts.merge({
        recycle_rate: 1
      }))
      vopt = voter_opts.merge({
        campaign: @campaign,
        enabled: true
      })
      create_list(:voter, 10, vopt)
      Voter.count.should eq 10
      @voters = @campaign.all_voters
      last_call_time = 20.hours.ago
      @voters.order('id ASC').each do |v|
        v.update_attribute(:last_call_attempt_time, last_call_time)
        last_call_time += 1.hour
      end
    end

    def skip_voters(voters)
      voters.each{|v| v.update_attribute('skipped_time', 20.minutes.ago) }
    end

    # context 'not all voters have a last_call_attempt_time' do
    #   before do
    #     setup_voters
    #     @voters[3..6].each do |v|
    #       v.update_attribute(:last_call_attempt_time, nil)
    #     end
    #   end


    # end

    context 'current_voter_id is not present' do
      before do
        setup_voters
      end
      context 'all voters have been skipped' do
        it 'returns the first voter with the oldest last_call_attempt_time' do
          skip_voters @voters
          actual = Voter.next_recycled_voter(@voters, 1, [], nil)
          expected = @voters.first
          actual.should eq expected
        end
      end
      context 'one voter has not been skipped' do
        it 'returns the first unskipped voter' do
          skip_voters @voters[0..7]
          expected = @voters[8]
          actual = Voter.next_recycled_voter(@voters, 1, [], nil)
          actual.should eq expected
        end
      end
      context 'more than one voter has not been skipped' do
        it 'returns the first unskipped voter with the oldest last_call_attempt_time' do
          skip_voters @voters[3..7]
          expected = @voters[0]
          actual = Voter.next_recycled_voter(@voters, 1, [], nil)
          actual.should eq expected
        end
      end
    end

    context 'current_voter_id is present' do
      before do
        setup_voters
        @current_voter = @voters[3]
      end
      context 'all voters have been skipped' do
        it 'returns the voter with id > current_voter_id' do
          skip_voters @voters
          expected = @voters[4]
          actual = Voter.next_recycled_voter(@voters, 1, [], @current_voter.id)
          actual.should eq expected
        end
      end
      context 'one voter has not been skipped' do
        it 'returns the unskipped voter with id > current_voter_id' do
          skip_voters @voters[0..2]
          skip_voters @voters[4..7]
          skip_voters [@voters[9]]
          expected = @voters[8]
          actual = Voter.next_recycled_voter(@voters, 1, [], @current_voter.id)
          actual.should eq expected
        end
      end
      context 'more than one voter has not been skipped' do
        it 'returns the first unskipped voter with id > current_voter_id' do
          skip_voters @voters[0..2]
          skip_voters @voters[5..6]
          expected = @voters[4]
          actual = Voter.next_recycled_voter(@voters, 1, [], @current_voter.id)
          actual.should eq expected
        end
      end
    end
  end
end
