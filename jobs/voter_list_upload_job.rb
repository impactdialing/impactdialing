require 'resque/errors'
require 'impact_platform/heroku'
require 'librato_resque'

##
# Upload a new +VoterList+, importing +Voter+ records.
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
class VoterListUploadJob
  extend ImpactPlatform::Heroku::UploadDownloadHooks
  extend LibratoResque

  @queue = :upload_download

  def self.perform(voter_list_id, email, domain, callback_url, strategy="webui")
    begin
      ActiveRecord::Base.verify_active_connections!
      voter_list = VoterList.find(voter_list_id)
      job = VoterListJob.new( voter_list.id , domain, email, callback_url, strategy="webui")
      job.perform
      Resque.enqueue(ResetVoterListCounterCache, voter_list_id)
    rescue Resque::TermException
      Resque.enqueue(self, voter_list_id, email, domain, callback_url, strategy)
    end
  end
end
