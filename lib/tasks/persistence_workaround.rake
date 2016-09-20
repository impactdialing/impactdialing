namespace :persistence_workaround do
  desc "Fix issues with persisting data from Redis to MySQL"
  task :fix_lead_mismatch => [:environment] do
    rs = Sidekiq::RetrySet.new
    rs.each do |job|
      begin
        call_sid = job.args[2]
        cf = CallFlow::Persistence::Call::Completed.new(TWILIO_ACCOUNT, call_sid)
        leads = cf.leads.send(:leads)
        cf.dialed_call.storage[:lead_uuid] = leads.first["uuid"]
      rescue Exception => e
        puts 'Could not fix ' + call_sid
      end
    end
  end
end
