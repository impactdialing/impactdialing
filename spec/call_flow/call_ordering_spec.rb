require 'spec_helper'

describe 'Voters (Contacts) are called in the order they are uploaded', data_heavy: true do
  include FakeCallData

  it '1 caller on Preview' do
    expect(Voter.count).to eq 0
    admin       = create(:user)
    account     = admin.account
    campaign    = create_campaign_with_script(:bare_preview, account).last
    voters      = add_voters(campaign, :bare_voter, 50)
    callers     = add_callers(campaign, 1)

    full_passes = 3
    prev_voter  = nil
    action_pass = 1
    completed   = []
    failed      = []
    skipped     = []
    busy        = []

    full_passes.times do |outer_pass|
      outer_pass += 1

      if outer_pass > 1
        campaign.reload
        voters = Voter.all
        v = voters.first
        expect(v.status).to eq 'Call failed'
        expect(campaign.call_attempts).to include(v.last_call_attempt)
      end

      if !completed.empty? and !failed.empty?
        sans = completed.size + failed.size
        completed   = []
        failed      = []
        skipped     = []
        busy        = []
      else
        sans = 0
      end
      last_action_pass = 0
      (voters.count - sans).times do |inner_pass|
        inner_pass += 1

        voter = campaign.next_voter_in_dial_queue(prev_voter)
        next if voter.nil?
        
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

        last_action_pass = action_pass
      end

      # try to fail early
      case outer_pass
      when 1
        v = Voter.first
        expect(v.status).to eq 'Call failed'
        expect(campaign.call_attempts).to include(v.last_call_attempt)

        expect(failed.size).to eq 10
        expect(completed.size).to eq 10
        expect(skipped.size).to eq 10
        expect(busy.size).to eq 20

        expect(campaign.call_attempts.count).to eq 50 - skipped.size
        expect(voters.inject(0){|m,v| m += v.call_attempts.count}).to eq 50 - skipped.size
      when 2
        expect(failed.size).to eq 6
        expect(completed.size).to eq 6
        expect(busy.size).to eq 12
        expect(skipped.size).to eq 6

        expect(campaign.call_attempts.count).to eq 40 + (30 - skipped.size)
      end

      actual   = Voter.available_for_retry(campaign).count + Voter.not_dialed.count
      expected = [nil,30,18,3][outer_pass]
      expect(actual).to eq(expected), [
        "Incorrect number of voters available for retry",
        "expected: #{expected}",
        "got: #{actual}",
        "outer_pass: #{outer_pass}",
        "last_action_pass: #{last_action_pass}",
        "sans: #{sans}",
        "available for retry count: #{Voter.available_for_retry(campaign).count}",
        "NOT available for retry count: #{Voter.not_available_for_retry(campaign).count}",
        "not dialed count: #{Voter.not_dialed.count}"
      ].join("\n")

      actual   = Voter.not_available_for_retry(campaign).count
      expected = [nil,20,32,47][outer_pass]
      expect(actual).to eq(expected), [
        "Incorrect number of voters NOT available for retry",
        "expected: #{expected}",
        "got: #{actual}",
        "outer_pass: #{outer_pass}",
        "last_action_pass: #{last_action_pass}",
        "sans: #{sans}",
        "available for retry count: #{Voter.available_for_retry(campaign).count}",
        "NOT available for retry count: #{Voter.not_available_for_retry(campaign).count}",
        "not dialed count: #{Voter.not_dialed.count}"
      ].join("\n")
    end
  end
end
