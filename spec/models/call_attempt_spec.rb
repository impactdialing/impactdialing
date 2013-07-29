require "spec_helper"

describe CallAttempt do
  include Rails.application.routes.url_helpers

  it "lists all attempts for a campaign" do
    campaign = create(:campaign)
    attempt_of_our_campaign = create(:call_attempt, :campaign => campaign)
    attempt_of_another_campaign = create(:call_attempt, :campaign => create(:campaign))
    CallAttempt.for_campaign(campaign).to_a.should =~ [attempt_of_our_campaign]
  end

  it "lists all attempts by status" do
    delivered_attempt = create(:call_attempt, :status => "Message delivered")
    successful_attempt = create(:call_attempt, :status => "Call completed with success.")
    CallAttempt.for_status("Message delivered").to_a.should =~ [delivered_attempt]
  end

  it "rounds up the duration to the nearest minute" do
    now = Time.now
    call_attempt = create(:call_attempt, call_start:  Time.now, connecttime:  Time.now, call_end:  (Time.now + 150.seconds))
    Time.stub(:now).and_return(now + 150.seconds)
    call_attempt.duration_rounded_up.should == 3
  end

  it "rounds up the duration up to now if the call is still running" do
    now = Time.now
    call_attempt = create(:call_attempt, call_start:  now, connecttime:  Time.now, call_end:  nil)
    Time.stub(:now).and_return(now + 1.minute + 30.seconds)
    call_attempt.duration_rounded_up.should == 2
  end

  it "reports 0 minutes if the call hasn't even started" do
    call_attempt = create(:call_attempt, call_start: nil, connecttime:  Time.now, call_end:  nil)
    call_attempt.duration_rounded_up.should == 0
  end

  it "should abandon call" do
    voter = create(:voter)
    call_attempt = create(:call_attempt, :voter => voter)
    now = Time.now
    call_attempt.abandoned(now)
    call_attempt.status.should eq(CallAttempt::Status::ABANDONED)
    call_attempt.connecttime.should eq(now)
    call_attempt.call_end.should eq(now)
  end


  it "should end_answered_by_machine" do
    voter = create(:voter)
    call_attempt = create(:call_attempt, :voter => voter)
    now = Time.now
    nowminus2 = now - 2.minutes
    call_attempt.end_answered_by_machine(nowminus2, now)
    call_attempt.connecttime.should eq(nowminus2)
    call_attempt.call_end.should eq(now)
    call_attempt.wrapup_time.should eq(now)
  end

  it "should end_unanswered_call" do
    voter = create(:voter)
    call_attempt = create(:call_attempt, :voter => voter)
    now = Time.now
    call_attempt.end_unanswered_call("busy",now)
    call_attempt.status.should eq("No answer busy signal")
    call_attempt.call_end.should eq(now)
  end


  it "should disconnect call" do
     voter = create(:voter)
     call_attempt = create(:call_attempt, :voter => voter)
     caller = create(:caller)
     now = Time.now
     call_attempt.disconnect_call(now, 12, "url", caller.id)
     call_attempt.status.should eq(CallAttempt::Status::SUCCESS)
     call_attempt.call_end.should eq(now)
     call_attempt.recording_duration.should eq(12)
     call_attempt.recording_url.should eq("url")
     call_attempt.caller_id.should eq(caller.id)
   end

   it "can be scheduled for later" do
     voter = create(:voter)
     call_attempt = create(:call_attempt, :voter => voter)
     scheduled_date = "10/10/2020 20:20"
     call_attempt.schedule_for_later(scheduled_date)
     call_attempt.status.should eq(CallAttempt::Status::SCHEDULED)
     call_attempt.scheduled_date.should eq(scheduled_date)
   end


  it "should wrapup call webui" do
    voter = create(:voter)
    call_attempt = create(:call_attempt, :voter => voter)
    now = Time.now
    call_attempt.wrapup_now(now, CallerSession::CallerType::TWILIO_CLIENT)
    call_attempt.wrapup_time.should eq(now)
    call_attempt.voter_response_processed.should be_false
  end

  it "should wrapup call phones" do
    voter = create(:voter)
    caller = create(:caller, is_phones_only: true)
    call_attempt = create(:call_attempt, :voter => voter, :caller => caller)
    now = Time.now
    call_attempt.wrapup_now(now, CallerSession::CallerType::PHONE)
    call_attempt.wrapup_time.should eq(now)
    call_attempt.voter_response_processed.should be_true
  end

  it "should wrapup call phones" do
    voter = create(:voter)
    caller = create(:caller, is_phones_only: false)
    call_attempt = create(:call_attempt, :voter => voter, caller: caller)
    now = Time.now
    call_attempt.wrapup_now(now, CallerSession::CallerType::PHONE)
    call_attempt.wrapup_time.should eq(now)
    call_attempt.voter_response_processed.should be_false
  end

  it "should connect lead to caller" do
    voter = create(:voter)
    call_attempt = create(:call_attempt, :voter => voter)
    caller_session = create(:caller_session)
    RedisOnHoldCaller.should_receive(:longest_waiting_caller).and_return(caller_session.id)
    call_attempt.connect_caller_to_lead(DataCentre::Code::TWILIO)
    caller_session.attempt_in_progress.should eq(call_attempt)
    caller_session.voter_in_progress.should eq(voter)
  end



  it "lists attempts between two dates" do
    too_old = create(:call_attempt).tap { |ca| ca.update_attribute(:created_at, 10.minutes.ago) }
    too_new = create(:call_attempt).tap { |ca| ca.update_attribute(:created_at, 10.minutes.from_now) }
    just_right = create(:call_attempt).tap { |ca| ca.update_attribute(:created_at, 8.minutes.ago) }
    another_just_right = create(:call_attempt).tap { |ca| ca.update_attribute(:created_at, 8.minutes.from_now) }
    CallAttempt.between(9.minutes.ago, 9.minutes.from_now)
  end

  describe 'status filtering' do
    before(:each) do
      @wanted_attempt = create(:call_attempt, :status => 'foo')
      @unwanted_attempt = create(:call_attempt, :status => 'bar')
    end

    it "filters out attempts of certain statuses" do
      CallAttempt.without_status(['bar']).should == [@wanted_attempt]
    end

    it "filters out attempts of everything but certain statuses" do
      CallAttempt.with_status(['foo']).should == [@wanted_attempt]
    end
  end

  describe "call attempts between" do
    it "should return cal attempts between 2 dates" do
      create(:call_attempt, created_at: Time.now - 10.days)
      create(:call_attempt, created_at: Time.now - 1.month)
      call_attempts = CallAttempt.between(Time.now - 20.days, Time.now)
      call_attempts.length.should eq(1)
    end
  end

  describe "total call length" do
    it "should include the wrap up time if the call has been wrapped up" do
      call_attempt = create(:call_attempt, call_start:  Time.now - 3.minute, connecttime:  Time.now - 3.minute, wrapup_time:  Time.now)
      total_time = (call_attempt.wrapup_time - call_attempt.call_start).to_i
      call_attempt.duration_wrapped_up.should eq(total_time)
    end

    it "should return the duration from start to now if call has not been wrapped up " do
      call_attempt = create(:call_attempt, call_start: Time.now - 3.minute, connecttime:  Time.now - 3.minute)
      total_time = (Time.now - call_attempt.call_start).to_i
      call_attempt.duration_wrapped_up.should eq(total_time)
    end
  end


  describe "wrapup call_attempts" do
    it "should wrapup all call_attempts that are not" do
      caller = create(:caller)
      another_caller = create(:caller)
      create(:call_attempt, caller_id: caller.id)
      create(:call_attempt, caller_id: another_caller.id)
      create(:call_attempt, caller_id: caller.id)
      create(:call_attempt, wrapup_time: Time.now-2.hours,caller_id: caller.id)
      CallAttempt.not_wrapped_up.find_all_by_caller_id(caller.id).length.should eq(2)
      CallAttempt.wrapup_calls(caller.id)
      CallAttempt.not_wrapped_up.find_all_by_caller_id(caller.id).length.should eq(0)
    end
  end

  describe "payments" do

    describe "debit for calls" do
      it "should not debit if call not ended" do
        call_attempt = create(:call_attempt, call_end: (Time.now - 3.minutes))
        Payment.should_not_receive(:debit_call_charge)
        call_attempt.debit
      end

      it "should not debit if call not connected" do
        call_attempt = create(:call_attempt, connecttime: (Time.now - 3.minutes))
        Payment.should_not_receive(:debit_call_charge)
        call_attempt.debit
      end

      it "should not debit if manual subscription type" do
        account = create(:account, subscription_name: Account::Subscription_Type::MANUAL)
        campaign = create(:campaign, account: account)
        call_attempt = create(:call_attempt, connecttime: (Time.now - 3.minutes), call_end: (Time.now - 2.minutes), campaign: campaign)
        Payment.should_not_receive(:debit_call_charge)
        call_attempt.debit
      end

      it "should  debit if call connected " do
        account = create(:account, subscription_name: Account::Subscription_Type::PER_MINUTE)
        campaign = create(:campaign, account: account)
        payment = create(:payment, account: account, amount_remaining: 10.0)
        call_attempt = create(:call_attempt, tStartTime: (Time.now - 3.minutes), tEndTime: (Time.now - 2.minutes), campaign: campaign, tDuration: 60)
        Payment.should_receive(:where).and_return([payment])
        payment.should_receive(:debit_call_charge)
        account.should_receive(:check_autorecharge)
        call_attempt.debit
        call_attempt.save
        call_attempt.payment_id.should_not be_nil
      end

    end

    describe "call_time" do
      it "should give correct call time" do
        call_attempt = create(:call_attempt, tStartTime: (Time.now - 3.minutes), tEndTime: (Time.now - 2.minutes),  tDuration: 62)
        call_attempt.call_time.should eq(2)
      end
    end

    describe "amount_to_debit" do

      it "should retrun amount to debit" do
        call_attempt = create(:call_attempt, tStartTime: (Time.now - 3.minutes), tEndTime: (Time.now - 2.minutes), tDuration: 62)
        call_attempt.amount_to_debit.should eq(0.18)
      end

    end

    describe "determine_call_cost" do

      it "should return .02 for per caller" do
        account = create(:account, subscription_name: Account::Subscription_Type::PER_CALLER)
        campaign = create(:campaign, account: account)
        call_attempt = create(:call_attempt, connecttime: (Time.now - 3.minutes), call_end: (Time.now - 2.minutes), campaign: campaign)
        call_attempt.determine_call_cost.should eq(0.02)
      end

      it "should return .09 for per minute" do
        account = create(:account, subscription_name: Account::Subscription_Type::PER_MINUTE)
        campaign = create(:campaign, account: account)
        call_attempt = create(:call_attempt, connecttime: (Time.now - 3.minutes), call_end: (Time.now - 2.minutes), campaign: campaign)
        call_attempt.determine_call_cost.should eq(0.09)
      end

    end

  end
end
