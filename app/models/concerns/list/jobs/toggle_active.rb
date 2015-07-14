require 'librato_resque'

##
# Add/remove leads (Voters) associated with an enabled/disabled VoterList.
#

class List::Jobs::ToggleActive
  extend LibratoResque

  @queue = :import

  def self.perform(voter_list_id, enabled)
    voter_list = VoterList.find voter_list_id
    trimmer    = List::DisabledTrimmer.new(voter_list)
    if voter_list.enabled
      trimmer.add_enabled_leads
    else
      trimmer.remove_disabled_leads
    end
  end
end
