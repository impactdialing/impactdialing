require 'resque/errors'
require Rails.root.join("jobs/heroku_resque_auto_scale")
class VoterListChangeJob
  extend ::HerokuResqueAutoScale
  @queue = :upload_download

  class << self

    def perform(voter_list_id, enabled)
      begin
        p "VoterListChangeJob performing..."
        voter_list = VoterList.find(voter_list_id)
        voter_list.voter_ids.each_slice(500) do |ids|
          Voter.where(id: ids).update_all(enabled: enabled)
        end
        p "VoterListChangeJob done."
      rescue Resque::TermException, ActiveRecord::StatementInvalid => exception
        handle_exception(voter_list_id, enabled, exception)
      end
    end

    def requeue(voter_list_id, enabled)
      Resque.enqueue(self, voter_list_id, enabled)
    end

    def handle_exception(voter_list_id, enabled, exception)
      if exception.kind_of? ActiveRecord::StatementInvalid
        mailer         = ExceptionMailer.new(exception)
        mailer.notify_if_deadlock_detected
        if mailer.deadlock_detected?
          requeue(voter_list_id, enabled)
        else
          raise exception
        end
      else
        requeue(voter_list_id, enabled)
      end
    end

    def after_perform_scale_down(*args)
      HerokuResqueAutoScale::Scaler.workers('upload_download',1) if HerokuResqueAutoScale::Scaler.working_job_count('upload_download') == 1
    end

    def after_enqueue_scale_up(*args)
      workers_to_scale = HerokuResqueAutoScale::Scaler.working_job_count('upload_download') + HerokuResqueAutoScale::Scaler.pending_job_count('upload_download') - HerokuResqueAutoScale::Scaler.worker_count('upload_download')
      if workers_to_scale > 0 && HerokuResqueAutoScale::Scaler.working_job_count('upload_download') < 11
        HerokuResqueAutoScale::Scaler.workers('upload_download', (HerokuResqueAutoScale::Scaler.working_job_count('upload_download') + HerokuResqueAutoScale::Scaler.pending_job_count('upload_download')))
      end
    end

  end


end
