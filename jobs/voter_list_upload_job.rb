require 'resque/errors'
require Rails.root.join("jobs/heroku_resque_auto_scale")
class VoterListUploadJob
  extend ::HerokuResqueAutoScale
  @queue = :upload_download

  class << self

    def perform(voter_list_id, email, domain, callback_url, strategy="webui")
      begin
        ActiveRecord::Base.verify_active_connections!
        voter_list = VoterList.find(voter_list_id)
        job = VoterListJob.new( voter_list.id , domain, email, callback_url, strategy="webui")
        job.perform
      rescue Resque::TermException
        Resque.enqueue(self, voter_list_id, email, domain, callback_url, strategy)
      end
    end

    def after_perform_scale_down(*args)
      HerokuResqueAutoScale::Scaler.workers('upload_download',1) if HerokuResqueAutoScale::Scaler.working_job_count('upload_download') == 1
    end

    def after_enqueue_scale_up(*args)
      return if ["development", "test"].include?(ENV['RAILS_ENV'])
      workers_to_scale = HerokuResqueAutoScale::Scaler.working_job_count('upload_download') + HerokuResqueAutoScale::Scaler.pending_job_count('upload_download') - HerokuResqueAutoScale::Scaler.worker_count('upload_download')
      if workers_to_scale > 0 && HerokuResqueAutoScale::Scaler.working_job_count('upload_download') < 11
        HerokuResqueAutoScale::Scaler.workers('upload_download', (HerokuResqueAutoScale::Scaler.working_job_count('upload_download') + HerokuResqueAutoScale::Scaler.pending_job_count('upload_download')))
      end
    end

  end


end
