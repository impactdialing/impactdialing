require 'spec_helper'

describe 'CallFlow::DialQueue' do
  include FakeCallData

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
      expected = @campaign.households.map(&:phone)
      actual   = @dial_queue.available.all

      expect(actual).to eq expected
    end

    context 'partitioning voters by available state' do
      before do
        @dial_queue.clear
        # last 90 were busy
        Household.order('id DESC').limit(90).update_all(status: CallAttempt::Status::BUSY, presented_at: 5.minutes.ago)
        li = Household.order('id DESC').limit(90).last.id
        # 5 before that completed and are done
        households = Household.order('id DESC').where('id < ?', li).limit(5)
        households.update_all(status: CallAttempt::Status::SUCCESS, presented_at: 2.minutes.ago)
        households.each{|household| household.voters.update_all(status: CallAttempt::Status::SUCCESS)}
        @dial_queue.cache_all(@campaign.reload.all_voters) # 5 available, 90 recycled
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

  describe 'dialing through available' do
    it 'retrieve one phone number' do
      expected = [Household.first.phone]
      actual   = @dial_queue.next(1)

      expect(actual).to eq expected
    end

    it 'retrieves multiple phone numbers' do
      expected = Household.limit(10).map(&:phone)
      actual   = @dial_queue.next(10)

      expect(actual).to eq expected
    end

    it 'moves retrieved phone number(s) from :active queue to :presented' do
      phones           = @dial_queue.next(5)
      remaining_phones = @dial_queue.available.all(:active, with_scores: false)
      presented_phones = @dial_queue.available.all(:presented, with_scores: false)

      expect(phones).to eq presented_phones

      phones.each do |dialed|
        expect(remaining_phones).to_not include dialed
      end
    end
  end

  # describe 'when a call ends' do
  #   let(:phone_number){ @dial_queue.next(1).first }
  #   let(:twilio_params) do
  #     {
  #       'AccountSid' => 'AC123',
  #       'CallSid' => 'CA321',
  #       'To' => phone_number,
  #       'From' => '5554443322'
  #     }
  #   end
  #   # let(:voter){ Household.where(phone: phone_numbers).voters.first }
  #   # let(:other_voter){ create(:realistic_voter, campaign: voter.campaign, household: voter.household) }

  #   context 'call was not answered' do
  #     context 'CallStatus is failed' do
  #       let(:params) do
  #         twilio_params.merge({'CallStatus' => 'failed'})
  #       end
  #       before do
  #         @dial_queue.dialed(params)
  #       end
  #       it 'removes phone number from :presented set' do
  #         expect(@dial_queue.available.all(:presented)).to_not include(phone_number)
  #       end
  #       it 'does not add phone number to recycle bin' do
  #         expect(@dial_queue.recycle_bin.missing?(phone_number)).to be_truthy
  #       end
  #     end

  #     context 'CallStatus is busy or no-answer' do
  #       it 'removes phone number from :presented set'
  #       it 'adds phone number to recycle bin'
  #     end
  #   end

  #   context 'call was answered' do
  #     context 'by human' do
  #       context 'and connected' do
  #         it 'removes phone number from :presented set'

  #         context 'disposition results indicate the voter should be called again' do
  #           it 'adds phone number to recycle bin'
  #         end
  #         context 'disposition results indicate the voter should not be called again' do
  #           context 'this is the last voter of the household to be contacted' do
  #             it 'does not add the phone number to recycle bin'
  #           end
  #           context 'other voters of the household should be contacted' do
  #             it 'adds the phone number to recycle bin'
  #           end
  #         end
  #       end

  #       context 'and abandoned' do
  #         it 'removes phone number from :presented set'
  #         it 'adds the phone number to recycle bin'
  #       end
  #     end

  #     context 'by machine' do
  #       it 'removes phone number from :presented set'
  #       context 'campaign is configured to hangup' do
  #         it 'adds phone number to recycle bin'
  #       end
  #       context 'campaign is configured to drop message' do
  #         context 'and call back after message drop' do
  #           it 'adds phone number to recycle bin'
  #         end
  #         context 'and not call back after message drop' do
  #           it 'does not add phone number to recycle bin'
  #         end
  #       end
  #     end
  #   end
  # end
end
