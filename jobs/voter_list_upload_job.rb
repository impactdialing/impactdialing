class VoterListUploadJob 
  extend ::HerokuResqueAutoScale
  @queue = :worker_job

   def self.perform(separator, column_headers, csv_to_system_map, filename, voter_list_name, campaign_id, account_id, domain, email, callback_url, strategy="webui")
     job = VoterListJob.new(separator, column_headers, csv_to_system_map, filename, voter_list_name, campaign_id, account_id, domain, email, callback_url, strategy="webui")
     job.perform
   end
   
end