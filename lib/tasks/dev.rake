desc "populate dashboard"
task :populate_dashboard, [:caller_id] => [:environment] do |task, args|
require 'uuid'
  # Assume we have Active Campaign in MySQL. Might look into writing tests later for creating Campaign.
  campaign = Campaign.active.last
  params = {"account_sid" => 1, "sid" => UUID.new.generate}
  caller_session = campaign.caller_sessions.create!({
    caller_id: args[:caller_id],
    on_call: true,
    sid: params["sid"]
  })
  CallFlow::CallerSession.create(params)
end

task :update_redis_status => [:environment] do
  campaign = Campaign.active.last
  caller_session = campaign.caller_sessions.last
  RedisStatus.set_state_changed_time(campaign, "On call", caller_session)
end

task :delete_redis_status => [:environment] do
  campaign = Campaign.active.last
  caller_session = campaign.caller_sessions.last
  RedisStatus.delete_state(campaign, caller_session)
end
