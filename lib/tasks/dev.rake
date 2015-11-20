desc "populate dashboard"
task :populate_dashboard => [:environment] do
  # Assume we have Active Campaign in MySQL. Might look into writing tests later for creating Campaign.
  campaign = Campaign.active.last
  campaign.caller_sessions.create!({
    caller: campaign.callers.last,
    on_call: true
  })

  caller_session = CallerSession.last
  RedisStatus.set_state_changed_time(campaign.id, "On hold", caller_session.id)
  array = RedisStatus.state_time(campaign.id, caller_session.id)
  if array.empty?
    puts "didn't work"
  else
    puts "Worked"
  end
end
