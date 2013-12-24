require "spec_helper"


describe Preview do

  describe "next voter to be dialed" do
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

    it "returns priority  not called voter first" do
      campaign = create(:preview)
      voter = create(:voter, :status => 'not called', :campaign => campaign)
      priority_voter = create(:voter, :status => 'not called', :campaign => campaign, priority: "1")
      caller_session = create(:caller_session)
      campaign.next_voter_in_dial_queue(nil).should == priority_voter
    end

    it "returns uncalled voter before called voter" do
      campaign = create(:preview)
      caller_session = create(:caller_session)
      create(:voter, :status => CallAttempt::Status::SUCCESS, :last_call_attempt_time => 2.hours.ago, :campaign => campaign)
      uncalled_voter = create(:voter, :status => Voter::Status::NOTCALLED, :campaign => campaign)
      campaign.next_voter_in_dial_queue(nil).should == uncalled_voter
    end

    it "returns any scheduled voter within a ten minute window before an uncalled voter" do
      campaign = create(:preview)
      caller_session = create(:caller_session)
      scheduled_voter = create(:voter, :status => CallAttempt::Status::SCHEDULED, :last_call_attempt_time => 2.hours.ago, :scheduled_date => 1.minute.from_now, :campaign => campaign)
      create(:voter, :status => Voter::Status::NOTCALLED, :campaign => campaign)
      campaign.next_voter_in_dial_queue(nil).should == scheduled_voter
    end

    it "returns next voter in list if scheduled voter is more than 10 minutes away from call" do
      campaign = create(:preview)
      caller_session = create(:caller_session)
      scheduled_voter = create(:voter, :status => CallAttempt::Status::SCHEDULED, :last_call_attempt_time => 2.hours.ago, :scheduled_date => 20.minute.from_now, :campaign => campaign)
      current_voter = create(:voter, :status => Voter::Status::NOTCALLED, :campaign => campaign)
      next_voter = create(:voter, :status => Voter::Status::NOTCALLED, :campaign => campaign)
      campaign.next_voter_in_dial_queue(current_voter.id).should == next_voter
    end


    it "returns voter with respect to a current voter" do
      campaign = create(:preview)
      caller_session = create(:caller_session)
      uncalled_voter = create(:voter, :status => Voter::Status::NOTCALLED, :campaign => campaign)
      current_voter = create(:voter, :status => Voter::Status::NOTCALLED, :campaign => campaign)
      next_voter = create(:voter, :status => Voter::Status::NOTCALLED, :campaign => campaign)
      campaign.next_voter_in_dial_queue(current_voter.id).should == next_voter
    end

    it "returns no number if only voter to be called a retry and last called time is within campaign recycle rate" do
      time_now = Time.now.utc
      Time.stub(:now).and_return(time_now)
      campaign = create(:preview, recycle_rate: 2)
      scheduled_voter = create(:voter, :first_name => 'scheduled voter', :status => CallAttempt::Status::SCHEDULED, :last_call_attempt_time => 2.hours.ago, :scheduled_date => 20.minutes.from_now, :campaign => campaign)
      retry_voter = create(:voter, :status => CallAttempt::Status::VOICEMAIL, last_call_attempt_time: 1.hours.ago, :campaign => campaign)
      current_voter = create(:voter, :status => CallAttempt::Status::SUCCESS, :campaign => campaign)
      campaign.next_voter_in_dial_queue(current_voter.id).should be_nil
    end

    it 'does not return any voter w/ a phone number in the blocked number list' do
      blocked = ['1234567890', '0987654321']
      campaign = create(:preview)
      campaign.stub(:blocked_numbers){ blocked }
      voter = create(:voter, :status => 'not called', :campaign => campaign, phone: blocked.first)
      priority_voter = create(:voter, :status => 'not called', :campaign => campaign, priority: "1", phone: blocked.second)
      caller_session = create(:caller_session)
      campaign.next_voter_in_dial_queue(nil).should be_nil
    end

    context 'current_voter_id is not present' do
      before do
        setup_voters
      end
      context 'all voters have been skipped' do
        it 'returns the first voter with the oldest last_call_attempt_time' do
          actual = @campaign.next_voter_in_dial_queue(nil)
          expected = @voters.first
          actual.should eq expected
        end
      end
      context 'one voter has not been skipped' do
        it 'returns the first unskipped voter' do
          skip_voters @voters[0..7]
          expected = @voters[8]
          actual = @campaign.next_voter_in_dial_queue(nil)
          actual.should eq expected
        end
      end
      context 'more than one voter has not been skipped' do
        it 'returns the first unskipped voter with the oldest last_call_attempt_time' do
          skip_voters @voters[3..7]
          expected = @voters[0]
          actual = @campaign.next_voter_in_dial_queue(nil)
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
        it 'returns the first voter to be dialed with id != current_voter_id' do
          skip_voters @voters
          expected = @voters[0]
          actual = @campaign.next_voter_in_dial_queue(@current_voter.id)
          actual.should eq expected
        end
      end
      context 'one voter has not been skipped' do
        it 'returns the unskipped voter with id > current_voter_id' do
          skip_voters @voters[0..2]
          skip_voters @voters[4..7]
          skip_voters [@voters[9]]
          expected = @voters[8]
          actual = @campaign.next_voter_in_dial_queue(@current_voter.id)
          actual.should eq expected
        end
      end
      context 'more than one voter has not been skipped' do
        it 'returns the first unskipped voter with id > current_voter_id' do
          skip_voters @voters[0..2]
          skip_voters @voters[5..6]
          expected = @voters[4]
          actual = @campaign.next_voter_in_dial_queue(@current_voter.id)
          actual.should eq expected
        end
      end
    end

    it 'does not cycle through a sub-set of available voters' do
      setup_voters
      expected = @voters[0]
      actual = @campaign.next_voter_in_dial_queue(nil)
      actual.should eq expected

      actual.skip
      actual.reload

      expected = @voters[1]
      actual = @campaign.next_voter_in_dial_queue(actual.id)
      actual.should eq expected

      actual.skip
      actual.reload

      expected = @voters[2]
      actual = @campaign.next_voter_in_dial_queue(actual.id)
      actual.should eq expected
    end

    it 'never returns the current voter when that voter has been skipped' do
      campaign = create(:preview)
      vopt = {
        campaign: campaign
      }
      vone = create(:voter, vopt)
      vtwo = create(:voter, vopt)
      vthr = create(:voter, vopt)

      campaign.next_voter_in_dial_queue(nil).should eq vone

      vone.reload.skip

      next_voter = campaign.next_voter_in_dial_queue(vone.id)
      next_voter.should_not eq vone
      next_voter.should eq vtwo

      vtwo.reload.skip

      next_voter = campaign.next_voter_in_dial_queue(vtwo.id)
      next_voter.should_not eq vtwo
      next_voter.should eq vthr
    end
  end
end
