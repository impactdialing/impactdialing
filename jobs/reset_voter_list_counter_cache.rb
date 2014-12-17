require 'librato_resque'

##
# Reset +VoterList#voters_count+ counter cache.
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
class ResetVoterListCounterCache
  extend LibratoResque

  @queue = :upload_download

  def self.perform(voter_list_id)
    VoterList.reset_counters(voter_list_id, :voters)
    list = VoterList.find voter_list_id
    Campaign.reset_counters(list.campaign_id, :households)
  end
end
