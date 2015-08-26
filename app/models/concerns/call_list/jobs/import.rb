require 'resque/errors'
require 'librato_resque'

##
# Process an uploaded VoterList file from S3.
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
class CallList::Jobs::Import
  extend LibratoResque

  @queue = :import

  def self.perform(voter_list_id, email=nil, cursor=0, results=nil)
    begin
      voter_list  = VoterList.includes(:campaign).find(voter_list_id)
      imports     = CallList::Imports.new(voter_list, cursor, results)
      imports.create_new_custom_voter_fields!

      imports.parse do |redis_keys, households|
        imports.save(redis_keys, households)
        cursor  = imports.cursor
        results = imports.results
      end

      # list/import.lua adds available numbers to pending during processing
      # this ensures that a household is not presented
      # until all related leads from same list have been collected
      imports.move_pending_to_available

      final_results = imports.final_results

      mailer(voter_list, email).try(:completed, final_results)

    rescue Resque::TermException, Redis::BaseConnectionError
      Resque.enqueue(self, voter_list_id, email, cursor, results.try(:to_json))
    end
  end
  
  # email can be nil when job is queued after initial import
  # which can happen eg when a user enables a disabled list
  def self.mailer(voter_list, email=nil)
    unless email.nil?
      VoterListMailer.new(email, voter_list)
    end
  end
end

