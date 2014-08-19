require 'spec_helper'

describe 'Voters (Contacts) are called in the order they are uploaded', data_heavy: true do
  include FakeCallData

  it '1 caller on Preview' do
    admin       = create(:user)
    account     = admin.account
    campaign    = create_campaign_with_script(:bare_preview, account).last
    voters      = add_voters(campaign, 50)
    callers     = add_callers(campaign, 1)

    data   = {}
    passes = {}

    full_passes = 3
    prev_voter  = nil
    action_pass = 1
    full_passes.times do |outer_pass|
      outer_pass += 1

      data[outer_pass] = {}

      if outer_pass > 1
        campaign.reload
        voters = Voter.all
        v = voters.first
        expect(v.status).to eq 'Call failed'
        expect(campaign.call_attempts).to include(v.last_call_attempt)
      end

      if defined?(completed) and defined?(failed)
        sans = completed.size + failed.size
      else
        sans = 0
      end

      completed   = []
      failed      = []
      skipped     = []
      busy        = []

      (voters.count - sans).times do |inner_pass|
        inner_pass += 1

        voter = campaign.next_voter_in_dial_queue(prev_voter)
        next if voter.nil?

        passes[voter.id] ||= 0
        passes[voter.id] += 1
        data[outer_pass][voter.id] = []
        # expect(voters[inner_pass-1]).to eq voter
        
        case action_pass
        when 1
          attach_call_attempt(:past_recycle_time_failed_call_attempt, voter)
          failed << voter.id
        when 2
          voter.skip
          skipped << voter.id
        when 3
          attach_call_attempt(:past_recycle_time_busy_call_attempt, voter)
          busy << voter.id
        when 4
          attach_call_attempt(:past_recycle_time_busy_call_attempt, voter)
          busy << voter.id
        when 5
          attach_call_attempt(:past_recycle_time_completed_call_attempt, voter)
          completed << voter.id
        end

        action_pass += 1
        action_pass  = 1 if action_pass > 5
        prev_voter   = voter

        data[outer_pass][voter.id] << {status: voter.status}
      end

      # case outer_pass
      # when 1
      #   v = Voter.first
      #   expect(v.status).to eq 'Call failed'
      #   expect(campaign.call_attempts).to include(v.last_call_attempt)

      #   expect(failed.size).to eq 10
      #   expect(completed.size).to eq 10
      #   expect(skipped.size).to eq 10
      #   expect(busy.size).to eq 20

      #   expect(campaign.call_attempts.count).to eq 50 - skipped.size
      #   expect(voters.inject(0){|m,v| m += v.call_attempts.count}).to eq 50 - skipped.size
      # when 2
      #   expect(failed.size).to eq 6
      #   expect(completed.size).to eq 6
      #   expect(busy.size).to eq 12
      #   expect(skipped.size).to eq 6

      #   expect(campaign.call_attempts).to eq 40 + (30 - skipped.size)

      #   [failed, skipped, busy, completed].each do |ids|
      #     vtrs = Voter.where(id: ids)
      #     cnts = vtrs.inject(0){|m,v| m += v.call_attempts.count}
      #     expect(cnts).to eq 2 * vtrs.count
      #   end
        
      # when 3
      #   expect(failed.size).to eq 4
      #   expect(completed.size).to eq 3
      #   expect(busy.size).to eq 7
      #   expect(skipped.size).to eq 4

      #   expect(campaign.call_attempts).to eq 50 + 30 + 18
      # end
    end

    # voters = Voter.includes(:call_attempts).all
    # total_attempts = 0
    # data = voters.map do |voter|
    #   total_attempts += voter.call_attempts.count

    #   {
    #     id: voter.id,
    #     attempts: {
    #       count: voter.call_attempts.count,
    #       statuses: voter.call_attempts.map(&:status).join('; ')
    #     }
    #   }
    # end
    
    # print "Voter ID, Attempts Counted, Attempt Statuses\n"
    # data.each do |item|
    #   print "#{item[:id]}, #{item[:attempts][:count]}, #{item[:attempts][:statuses]}\n"
    # end
    # print "Total Attempts Counted: #{total_attempts}\n"
    # print "Total Attempts Saved: #{campaign.call_attempts.count}\n"

    print "Voter ID, Pass, Status, Total Attempts, Total Passes\n"
    data.sort.each do |pass_voter_tuples|
      pass   = pass_voter_tuples[0]
      voters = pass_voter_tuples[1]

      voters.sort.each do |attempt_tuple|
        voter_id = attempt_tuple[0]
        items    = attempt_tuple[1]

        items.each do |item|
          print "#{voter_id}, #{pass}, #{item[:status]}, #{Voter.find(voter_id).call_attempts.count}, #{passes[voter_id]}\n"
        end
      end
    end
  end
end
