require 'resque/errors'
require 'impact_platform/heroku'
require 'librato_resque'

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
  extend ImpactPlatform::Heroku::UploadDownloadHooks
  extend LibratoResque

  @queue = :upload_download

  def self.perform(voter_list_id, enabled)
    begin
      voter_list = VoterList.find(voter_list_id)
      voter_list.voter_ids.each_slice(500) do |ids|
        bitmasks = []
        bitmasks << :list if enabled

        Voter.where(id: ids).blocked.update_all(enabled: Voter.bitmask_for_enabled(*[ bitmasks + [:blocked] ].flatten))
        Voter.where(id: ids).not_blocked.update_all(enabled: Voter.bitmask_for_enabled(*bitmasks))
      end
    rescue Resque::TermException, ActiveRecord::StatementInvalid => exception
      handle_exception(voter_list_id, enabled, exception)
      return
    end

    dial_queue = CallFlow::DialQueue.new(voter_list.campaign)
    dial_queue.refresh
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
