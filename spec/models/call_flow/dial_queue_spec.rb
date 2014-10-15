require 'spec_helper'

describe 'CallFlow::DialQueue' do
  include FakeCallData

  def clean_dial_queue
    @dial_queue.clear
  end

  let(:admin){ create(:user) }
  let(:account){ admin.account }

  before do
    @campaign = create_campaign_with_script(:bare_preview, account).last
    create_list(:realistic_voter, 100, {campaign: @campaign, account: account})
    @dial_queue = CallFlow::DialQueue.new(@campaign)
    @dial_queue.cache_all(@campaign.all_voters)
  end
  after do
    clean_dial_queue
  end

  describe 'caching voters available to be dialed' do
    it 'preserves ordering of voters' do
      expected = @campaign.all_voters.select([:id, :last_call_attempt_time, :phone]).map(&:phone)
      actual   = @dial_queue.peak(:available)
      expect(actual).to eq expected
    end

    context 'partitioning voters by available state' do
      before do
        @dial_queue.clear
        Voter.order('id DESC').limit(90).update_all(status: CallAttempt::Status::BUSY, last_call_attempt_time: 5.minutes.ago)
        li = Voter.order('id DESC').limit(90).last.id
        Voter.order('id DESC').where('id < ?', li).limit(5).update_all(status: CallAttempt::Status::SUCCESS)
        @dial_queue.cache_all(@campaign.reload.all_voters)
      end
      it 'pushes voters that can not be dialed right away to the recycle bin set' do
        expect(@dial_queue.size(:recycle_bin)).to eq 90
      end

      it 'pushes voters that can be dialed right away to the available set' do
        expect(@dial_queue.size(:available)).to eq 5
      end

      it 'avoids pushing members that are not available for dial and not eventually retriable' do
        # if the previous two pass, this one is good. more for documentation :)
      end
    end
  end

  describe 'retrieving voters' do
    it 'retrieve one voter' do
      expected = [Voter.order('id').select([:id, :last_call_attempt_time]).first.id]
      actual   = @dial_queue.next(1)

      expect(actual).to eq expected
    end

    it 'retrieves multiple voters' do
      expected = Voter.order('id').select([:id, :last_call_attempt_time]).limit(10).map(&:id)
      actual   = @dial_queue.next(10)

      expect(actual).to eq expected
    end

    it 'removes retrieved voter(s) from queue' do
      voter_ids    = @dial_queue.next(5)
      Voter.where(id: voter_ids).update_all(last_call_attempt_time: Time.now, status: CallAttempt::Status::BUSY)
      db_voters  = Voter.where(id: voter_ids)
      actual     = @dial_queue.available.peak
      unexpected = db_voters.map(&:phone)

      unexpected.each do |un|
        expect(actual).to_not include un
      end
    end
  end

  describe 'handling recycle bin voters' do
    let(:voter_ids){ @dial_queue.next(1) }
    let(:voter){ Voter.find(voter_ids.first) }
    let(:other_voter){ create(:realistic_voter, campaign: voter.campaign, phone: voter.phone) }

    it 'adds voter.phone to recycle bin set' do
      @dial_queue.process_dialed(voter)

      expect(@dial_queue.recycle_bin.all).to include voter.phone
    end

    context 'the dial completes and will not be retried' do
      before do
        @dial_queue.cache(other_voter)
      end

      it 'removes the voter.id from the set of household members' do
        voter.update_attributes!({
          status: CallAttempt::Status::SUCCESS,
          last_call_attempt_time: 5.minutes.ago,
          last_call_attempt_id: 42
        })
        @dial_queue.process_dialed(voter)

        remaining_members = @dial_queue.households.find(voter.phone)
        expect(remaining_members).to eq [other_voter.id]
      end

      context 'the just completed dial was to the last member of a household' do
        before do
          # make sure forgery didn't randomly create dup phone
          voter = Voter.last
          @dial_queue.remove(voter)
          voter.destroy
        end

        it 'removes the household' do
          ids = @dial_queue.next(1)
          last_member = Voter.find(ids.first)
          expect(Voter.where(phone: last_member.phone).count).to eq 1
          last_member.update_attributes!({
            status: CallAttempt::Status::SUCCESS,
            last_call_attempt_time: 5.minutes.ago,
            last_call_attempt_id: 42
          })
          @dial_queue.process_dialed(last_member)

          remaining_members = @dial_queue.households.find(last_member.phone)
          expect(remaining_members).to eq []
        end
      end
    end

    context 'the dial completes and will be retried' do
      before do
        @dial_queue.cache(other_voter)
      end

      it 'moves the voter.id to the last position in the set of household members' do
        voter.update_attributes!({
          status: Voter::Status::SKIPPED,
          skipped_time: 1.minute.ago
        })
        @dial_queue.process_dialed(voter)

        remaining_members = @dial_queue.households.find(voter.phone)
        expect(remaining_members).to eq [other_voter.id, voter.id]
      end
    end
  end
end
