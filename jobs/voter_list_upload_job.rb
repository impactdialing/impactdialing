require 'resque/plugins/lock'

class VoterListUploadJob 
  extend Resque::Plugins::Director
  direct :min_workers => 0, :max_workers => 10, :max_time => 60, :max_queue => 0, :wait_time => 30
  @queue = :voter_list

   def self.perform(separator, column_headers, csv_to_system_map, filename, voter_list_name, campaign_id, account_id, domain, email, callback_url, strategy="webui")
     job = VoterListJob.new(separator, column_headers, csv_to_system_map, filename, voter_list_name, campaign_id, account_id, domain, email, callback_url, strategy="webui")
     job.perform
   end
   
end