class ResetVoterListCounterCache
  @queue = :upload_download

  def self.perform(voter_list_id)
    VoterList.reset_counters(voter_list_id, :voters)
  end
end
