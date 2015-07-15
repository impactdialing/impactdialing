require 'librato_resque'

##
# Add/remove leads (Voters) associated with an enabled/disabled VoterList.
#

class List::Jobs::ToggleActive
  extend LibratoResque

  @queue = :import

  def self.perform(voter_list_id)
    voter_list = VoterList.find voter_list_id
    trimmer    = List::DisabledTrimmer.new(voter_list)
    if voter_list.enabled
      trimmer.enable_leads
    else
      trimmer.disable_leads
    end
  end
end
