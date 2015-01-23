require 'spec_helper'
require 'householding/migrate'

describe 'Householding::Migrate' do
  let(:account_one){ create(:account) }
  let(:account_two){ create(:account) }
  let(:account_one_campaigns){ create_list(:power, 4, account: account_one) }
  let(:account_two_campaigns){ create_list(:predictive, 4, account: account_two) }
  let(:phone){ PhoneNumber.sanitize(Forgery(:address).phone) }


    VOICEMAIL = 'Message delivered'
    SUCCESS = 'Call completed with success.'
    INPROGRESS = 'Call in progress'
    NOANSWER = 'No answer'
    ABANDONED = "Call abandoned"
    BUSY = "No answer busy signal"
    FAILED = "Call failed"
    HANGUP = "Hangup or answering machine" # Used when answered by machine and there is no recording to play for the message.
    READY = "Call ready to dial"
    CANCELLED = "Call cancelled"
    SCHEDULED = 'Scheduled for later'
    RINGING = "Ringing"

  let(:voter_traits) do
    [
      Voter::Status::NOTCALLED, Voter::Status::SKIPPED, CallAttempt::Status::VOICEMAIL,
      CallAttempt::Status::SUCCESS, CallAttempt::Status::INPROGRESS,CallAttempt::Status::NOANSWER,
      CallAttempt::Status::ABANDONED, CallAttempt::Status::BUSY, CallAttempt::Status::FAILED,
      CallAttempt::Status::HANGUP, CallAttempt::Status::READY, CallAttempt::Status::RINGING
    ]
  end

  let(:call_attempt_traits) do
    [:ready, :in_progress, :busy, :abandoned, :completed, :voicemail_delivered, :machine_hangup, :machine_answered]
  end

  def rand_time
    earlier = 1.year.ago.to_i
    now     = Time.now.to_i
    Time.at(rand(earlier..now))
  end

  before do
    4.times do |n|
      # account one
      voters = create_list(:voter, 20, account: account_one, campaign: account_one_campaigns[n])
      voters.first.update_attributes(enabled: [:list, :blocked])
      voters.last.update_attributes!(enabled: [])
      voters[1..-1].each do |voter|
        create(:bare_call_attempt, call_attempt_traits.sample, created_at: rand_time, voter: voter, campaign: account_one_campaigns[n])
        if voter.id % 2 == 0
          create(:bare_call_attempt, call_attempt_traits.sample, created_at: rand_time, voter: voter, campaign: account_one_campaigns[n])
        end
      end
      5.times do
        create(:voter, phone: phone, account: account_one, campaign: account_one_campaigns[n])
      end

      # account two
      voters = create_list(:voter, 20, account: account_two, campaign: account_two_campaigns[n])
      voters.first.update_attributes!(enabled: [:list, :blocked])
      voters.last.update_attributes!(enabled: [])
      voters[1..-1].each do |voter|
        create(:bare_call_attempt, call_attempt_traits.sample, created_at: rand_time, voter: voter, campaign: account_two_campaigns[n])
        if voter.id % 2 == 0
          create(:bare_call_attempt, call_attempt_traits.sample, created_at: rand_time, voter: voter, campaign: account_two_campaigns[n])
        end
      end
      5.times do
        create(:voter, phone: phone, account: account_two, campaign: account_two_campaigns[n])
      end
    end

    expect(Voter.with_enabled(:blocked).count).to eq 2 * 4
    expect(Voter.without_enabled(:list).count).to eq 2 * 4

    # factories create households
    Household.delete_all
    Voter.update_all(household_id: nil)
  end

  describe 'creating Households' do
    before do
      Householding::Migrate.voters(Campaign.all)
    end
    it 'creates a Household record for each unique Voter#phone w/in a Campaign' do
      expect(Household.group(:campaign_id).count).to eq Voter.group(:campaign_id).select('distinct phone').count
    end

    it 'each Voter is associated w/ a Household' do
      expect(Voter.where('household_id IS NULL').count).to be_zero
    end

    it 'each Household#phone matches all associated Voter#phone' do
      Household.includes(:voters).all.each do |household|
        member_numbers = household.voters.map(&:phone)

        expect(member_numbers.uniq.size).to eq 1
        expect(member_numbers.first).to eq household.phone
      end
    end

    it 'each Household#account matches all associated Voter#account' do
      Household.includes(:voters).all.each do |household|
        member_accounts = household.voters.map(&:account)

        expect(member_accounts.map(&:id).uniq.size).to eq 1
        expect(member_accounts.first).to eq household.account
      end
    end

    it 'each Household#campaign matches all associated Voter#campaign' do
      Household.includes(:voters).all.each do |household|
        member_campaigns = household.voters.map(&:campaign)

        expect(member_campaigns.map(&:id).uniq.size).to eq 1
        expect(member_campaigns.first).to eq household.campaign
      end
    end

    it 'removes :blocked from Voter#enabled' do
      expect(Voter.with_enabled(:blocked).count).to be_zero
    end

    context 'when Voter#enabled contains :blocked' do
      before do
        Household.delete_all
        Voter.update_all(household_id: nil)
      end
      context 'and Voter#campaign#blocked_numbers includes Voter#phone' do
        before do
          create(:blocked_number, account: account_one, number: phone)
          create(:blocked_number, account: account_two, number: phone)
          Householding::Migrate.voters(Campaign.all)
        end

        it 'adds :dnc to associated Household#blocked' do
          expect(Household.with_blocked(:dnc).group(:campaign_id).count).to(
            eq(Voter.where(phone: phone).group(:campaign_id).select('distinct phone').count)
          )
        end
      end

      context 'and Voter#voter_list#skip_wireless is true and number is in wireless block' do
        let(:fake_dnc){ double('WirelessList', prohibits?: false) }
        before do
          Voter.where(phone: phone).includes(:voter_list).each do |voter|
            voter.voter_list.update_attributes(skip_wireless: true)
          end

          allow(fake_dnc).to receive(:prohibits?).with(phone){ true }
          allow(Householding::Migrate).to receive(:dnc_wireless){ fake_dnc }
          Householding::Migrate.voters(Campaign.all)
        end

        it 'adds :cell to associated Household#blocked' do
          expect(Household.with_blocked(:cell).group(:campaign_id).count).to eq Voter.group(:campaign_id).where(phone: phone).select('distinct phone').count
        end
      end
    end

    context 'updating CallAttempts & Households status/presented_at w/ latest CallAttempt across members' do
      it 'updates CallAttempt#household_id' do
        expect(CallAttempt.where(household_id: nil).count).to be_zero
      end

      it ''
    end
  end
end
