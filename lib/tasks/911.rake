desc "Check if a campaign has violated its call back timing (aka recycle rate)"
task :verify_campaign_call_back_timing, [:campaign_id, :interval] => :environment do |t,args|
  campaign_id = args[:campaign_id]
  interval    = args[:interval]

  print %Q{
    select v.phone, ca1.dialer_mode, ca1.sid, count(ca1.id), ca1.voter_id, ca1.id
    from call_attempts ca1
    inner join call_attempts ca2 on ca1.voter_id=ca2.voter_id and ca1.id <> ca2.id
    inner join voters v on v.id=ca1.voter_id
    where ca1.campaign_id=#{campaign_id}
    and ca1.created_at >= NOW() - INTERVAL 14 DAY 
    and ca1.created_at <= ca2.created_at
    and ca1.created_at > ca2.created_at - INTERVAL #{interval} HOUR
    group by ca1.voter_id having count(ca1.id) > 1;
  }
end

desc "Determine impact when campaign has violated its call back timing (aka recycle rate)"
task :report_campaign_call_back_timing_impact, [:campaign_id, :interval] => :environment do |t,args|
  campaign_id = args[:campaign_id]
  interval    = args[:interval]
  # campaign_id = 4266
  campaign = Campaign.find campaign_id
  caller_connected_attempts = campaign.call_attempts.where('status = ?', CallAttempt::Status::SUCCESS).where("created_at >= NOW() - INTERVAL 17 DAY").group(:voter_id).count.reject{|i,n| n < 2}
  
  voter_total           = 0
  minute_total          = 0
  voter_connected_total = 0
  per_voter_call_count  = {}
  per_voter_detail      = {}
  per_voter_min         = {}
  campaign.all_voters.includes(:call_attempts).where(id: caller_connected_attempts.keys).find_in_batches do |voters|
    voters.each do |voter|
      next if caller_connected_attempts[voter.id] <= 1

      # are any call attempt times w/in recycle rate hours of each other?
      # (a-b).abs <= recycle_rate
      attempt_times = voter.call_attempts.map(&:created_at)
      print "Checking #{attempt_times}\n"
      combo = attempt_times.combination(2)
      print "Combo: #{combo}\n"
      violated = combo.select{|tuple| (tuple.first-tuple.last).abs < (campaign.recycle_rate*3600)}
      next if violated.empty?

      # yep. so collect some info for the affected calls/voters
      # # of voters affected, # of billable minutes burned
      voter_total                   += 1
      per_voter_call_count[voter.id] = violated.flatten.size
      attempts                       = voter.call_attempts.successful_call.where('status = ?', CallAttempt::Status::SUCCESS).select('distinct(id), created_at, tDuration, campaign_id, voter_id').where(created_at: violated.flatten).limit(violated.flatten.size - 1)
      per_voter_min[voter.id]        = attempts.sum('ceil(tDuration/60)').to_i
      minute_total                  += per_voter_min[voter.id]
    end
  end

  print [
    "Total voters impacted: #{voter_total}",
    "Total minutes billed that would not have been if recycle rate was respected: #{minute_total}"
  ].join("\n")

  print "Voter ID, Times called, Minutes burned\n"
  print per_voter_call_count.map{|i,n| "#{i},#{n},#{per_voter_min[i]}"}.join("\n")
  print "\n"
end
