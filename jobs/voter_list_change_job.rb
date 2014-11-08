require 'resque/errors'
require 'impact_platform/heroku'

##
# Sync +VoterList#enabled+ to +Voter#enabled+.
#
# ### Metrics
#
# - completed
# - failed
# - timing
#
# ### Monitoring
#
# Alert conditions:
#
# - 1 failure
#
class VoterListChangeJob
  @queue = :upload_download
  extend ImpactPlatform::Heroku::UploadDownloadHooks

  def self.perform(voter_list_id, enabled)
    metrics = ImpactPlatform::Metrics::JobStatus.started(self.to_s.underscore)

    begin
      voter_list = VoterList.find(voter_list_id)
      voter_list.voter_ids.each_slice(500) do |ids|
        Voter.where(id: ids).update_all(enabled: enabled)
      end
    rescue Resque::TermException, ActiveRecord::StatementInvalid => exception
      metrics.error
      handle_exception(voter_list_id, enabled, exception)
    end

    dial_queue = CallFlow::DialQueue.new(voter_list.campaign)
    dial_queue.refresh(:available)

    metrics.completed
  end

  def self.requeue(voter_list_id, enabled)
    Resque.enqueue(self, voter_list_id, enabled)
  end

  def self.handle_exception(voter_list_id, enabled, exception)
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
end
