require 'librato_resque'

##
# Add/remove leads (Voters) associated with an enabled/disabled VoterList.
#

class CallList::Jobs::ToggleActive
  extend LibratoResque

  @queue = :import

  def self.perform(voter_list_id)
    voter_list = VoterList.find voter_list_id
    trimmer    = CallList::DisabledTrimmer.new(voter_list)
    if voter_list.enabled
      trimmer.enable_leads
    else
      trimmer.disable_leads
    end
    campaign = voter_list.campaign
    dial_queue = campaign.dial_queue
    total_numbers = 0
    count_args    = ['-inf','+inf']
    total_numbers += dial_queue.available.count(:active, *count_args)
    total_numbers += dial_queue.available.count(:presented, *count_args)
    total_numbers += dial_queue.completed.count(:completed, *count_args)
    total_numbers += dial_queue.recycle_bin.count(:bin, *count_args)
    total_numbers += dial_queue.blocked.count(:blocked, *count_args)
    campaign.call_list.stats.reset('total_numbers', total_numbers)
  end
end
