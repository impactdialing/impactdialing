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

        Voter.where(id: ids).update_all(enabled: Voter.bitmask_for_enabled(*bitmasks))
        enqueue_cache_voters(voter_list.campaign_id, ids, enabled)
      end
    rescue Resque::TermException, ActiveRecord::StatementInvalid => exception
      handle_exception(voter_list_id, enabled, exception)
      return
    end
  end

  def self.enqueue_cache_voters(campaign_id, voter_ids, enabled)
    Resque.enqueue(CallFlow::Jobs::CacheVoters, campaign_id, voter_ids, enabled)
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
