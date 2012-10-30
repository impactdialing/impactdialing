require 'resque/errors'
require Rails.root.join("jobs/heroku_resque_auto_scale")
class VoterListChangeJob
  extend ::HerokuResqueAutoScale
  @queue = :list_upload

  class << self

    def perform(voter_list_id, enabled)
      begin
        voter_list = VoterList.find(voter_list_id)
        voter_list.voter_ids.each_slice(500) do |ids|
          Voter.where(id: ids).update_all(enabled: enabled)
        end
      rescue Resque::TermException
        Resque.enqueue(self, voter_list_id, email, domain, callback_url, strategy)
      end
    end

    def after_perform_scale_down(*args)
      HerokuResqueAutoScale::Scaler.workers('list_upload',1) if HerokuResqueAutoScale::Scaler.working_job_count('list_upload') == 1
    end

    def after_enqueue_scale_up(*args)
      workers_to_scale = HerokuResqueAutoScale::Scaler.working_job_count('list_upload') + HerokuResqueAutoScale::Scaler.pending_job_count('list_upload') - HerokuResqueAutoScale::Scaler.worker_count('list_upload')
      if workers_to_scale > 0 && HerokuResqueAutoScale::Scaler.working_job_count('list_upload') < 11
        HerokuResqueAutoScale::Scaler.workers('list_upload', (HerokuResqueAutoScale::Scaler.working_job_count('list_upload') + HerokuResqueAutoScale::Scaler.pending_job_count('list_upload')))
      end
    end

  end


end
