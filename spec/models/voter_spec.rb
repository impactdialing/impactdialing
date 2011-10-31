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
    Voter.by_status(Voter::Status::NOTCALLED).should == [voter1,voter2]
  end

  it "returns only active voters" do
    active_voter = Factory(:voter, :active => true)
    inactive_voter = Factory(:voter, :active => false)
    Voter.active.should == [active_voter]
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
      call_attempt.status.should == CallAttempt::Status::INPROGRESS
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
    let(:campaign) { Factory(:campaign, :robo => false, :predictive_type => 'algorithm1') }
    let(:voter) { Factory(:voter, :campaign => campaign) }
    let(:client) { mock(:client).tap{|client| Twilio::REST::Client.stub(:new).and_return(client) } }

    context 'making calls' do
      before(:each) do
        client.stub_chain(:account, :calls, :create).and_return(mock(:call, :sid => 'sid'))
      end

      it "is dialed" do
        voter.dial_predictive
        call_attempt = voter.call_attempts.last
        call_attempt.sid.should == "sid"
        call_attempt.status.should == CallAttempt::Status::INPROGRESS
      end

      it "updates voter attributes" do
        voter.dial_predictive
        call_attempt = voter.call_attempts.last
        voter.last_call_attempt.should == call_attempt
        time_now = Time.now
        Time.stub!(:now).and_return(time_now)
        DateTime.parse(voter.last_call_attempt_time.to_s).should == DateTime.parse(time_now.utc.to_s)
      end

      it "updates the call_attempts campaign" do
        voter.dial_predictive
        call_attempt = voter.call_attempts.last
        call_attempt.campaign.should == voter.campaign
      end
    end

    it "dials the voter and hangs up on answering machine when not using recordings" do
      client.stub_chain(:account, :calls, :create).with({:from => anything, :to => anything, :url => anything,'StatusCallback' => anything , 'IfMachine' => 'Hangup', 'Timeout' => 20}).and_return(mock(:call, :sid => 'sid'))
      campaign.use_recordings = false
      voter.dial_predictive
    end

    it "dials the voter and continues on answering machine when using recordings" do
      client.stub_chain(:account, :calls, :create).with({:from => anything, :to => anything, :url => anything, 'StatusCallback' => anything, 'IfMachine' => 'Continue', 'Timeout' => 20}).and_return(mock(:call, :sid => 'sid'))
      campaign.use_recordings = true
      voter.campaign = campaign
      voter.dial_predictive
    end

    it "dials the voter with the campaigns answer detection timeout" do
      campaign.use_recordings = true
      campaign.answer_detection_timeout = "10"
      client.stub_chain(:account, :calls, :create).with({:from => anything, :to => anything, :url => anything, 'StatusCallback' => anything, 'IfMachine' => 'Continue', 'Timeout' => campaign.answer_detection_timeout}).and_return(mock(:call, :sid => 'sid'))
      voter.campaign = campaign
      voter.dial_predictive
    end
  end

  describe "to be dialed" do
    it "includes voters never called" do
      voter = Factory(:voter)
      Voter.to_be_dialed.should == [voter]
    end

    it "includes voters with a busy signal" do
      voter = Factory(:voter)
      Factory(:call_attempt, :voter => voter, :status => CallAttempt::Status::BUSY)
      Voter.to_be_dialed.should == [voter]
    end

    (CallAttempt::Status::ALL - [CallAttempt::Status::SUCCESS]).each do |status|
      it "includes voters with a status of #{status} " do
        voter = Factory(:voter)
        Factory(:call_attempt, :voter => voter, :status => status)
        Voter.to_be_dialed.should == [voter]
      end
    end

    it "excludes voters with a status of a successful call" do
      voter = Factory(:voter)
      Factory(:call_attempt, :voter => voter, :status => CallAttempt::Status::SUCCESS)
      Voter.to_be_dialed.should be_empty
    end
  end

  describe "voter attributes" do
    let(:voter){ Factory(:voter, :campaign => Factory(:campaign, :account => Factory(:account)), :Phone => '384756923349') }

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

  it "lists scheduled voters" do
    recent_voter = Factory(:voter, :scheduled_date => 2.minutes.ago, :status => CallAttempt::Status::SCHEDULED)
    really_old_voter = Factory(:voter, :scheduled_date => 2.hours.ago, :status => CallAttempt::Status::SCHEDULED)
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
end
