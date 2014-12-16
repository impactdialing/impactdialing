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

    cache_available_voters(campaign)

    full_passes = 3
    prev_voter  = nil
    action_pass = 1
    all_results = {
      completed: [],
      failed: [],
      skipped: [],
      busy: []
    }
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
        # print "Failed (#{failed.size}):\t#{failed}\n"
        # print "Completed (#{completed.size}):\t#{completed}\n"
        # print "Skipped (#{skipped.size}):\t#{skipped}\n"
        # print "Busy (#{busy.size}):\t#{busy}\n"
        # print "\n\n"
        sans = all_results[:completed].size + all_results[:failed].size
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

        voter = campaign.next_in_dial_queue(prev_voter)
        if voter.nil?
          # p 'moving on'
          next 
        end
        
        last_action_pass = action_pass

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
          action_pass = 0
        end

        # print "Dialed: #{voter.id}, #{voter.phone} #{voter.status}\n"
        # print "Available: #{dial_queue.peak(:available).map{|v| JSON.parse(v)['id']}}\n"
        # print "Last Loaded ID: #{dial_queue.queues[:available].send(:last_loaded_id)}\n"
        
        prev_voter   = voter
        action_pass += 1
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
      when 3
        expect(failed.size).to eq 4
        expect(completed.size).to eq 3
        expect(skipped.size).to eq 4
        expect(busy.size).to eq 7
      end

      actual   = Voter.available_list(campaign).count
      expected = [nil,30,18,11][outer_pass]

      # binding.pry
      # if !completed.empty? and !failed.empty?
      #   print "Failed (#{failed.size}):\t#{failed}\n"
      #   print "Completed (#{completed.size}):\t#{completed}\n"
      #   print "Skipped (#{skipped.size}):\t#{skipped}\n"
      #   print "Busy (#{busy.size}):\t#{busy}\n"
      #   print "\n\n"
      # end

      all_results[:completed] += completed
      all_results[:failed]    += failed
      all_results[:busy]      += busy
      all_results[:skipped]   += skipped

      expect(actual).to eq(expected), [
        "Incorrect number of voters available for retry",
        "expected: #{expected}",
        "got: #{actual}",
        "outer_pass: #{outer_pass}",
        "last_action_pass: #{last_action_pass}",
        "sans: #{sans}",
        "available for retry count: #{Voter.available_for_retry(campaign).count}",
        "NOT available for retry count: #{Voter.not_available_for_retry(campaign).count}",
        "status counts: #{Voter.group('status').count}"
      ].join("\n")

      actual   = Voter.not_available_for_retry(campaign).count
      expected = [nil,20,32,39][outer_pass]
      expect(actual).to eq(expected), [
        "Incorrect number of voters NOT available for retry",
        "expected: #{expected}",
        "got: #{actual}",
        "outer_pass: #{outer_pass}",
        "last_action_pass: #{last_action_pass}",
        "sans: #{sans}",
        "available for retry count: #{Voter.available_for_retry(campaign).count}",
        "NOT available for retry count: #{Voter.not_available_for_retry(campaign).count}",
        "status counts: #{Voter.group('status').count}"
      ].join("\n")
    end
  end
end
