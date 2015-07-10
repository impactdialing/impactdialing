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
class List::Jobs::Import
  extend LibratoResque

  @queue = :import

  def self.perform(voter_list_id, email, cursor=0, results=nil)
    begin
      voter_list  = VoterList.includes(:campaign).find(voter_list_id)
      imports     = List::Imports.new(voter_list, cursor, results)

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

      mailer(email, voter_list).completed(final_results)

    # todo: requeue on timeouts etc
    rescue Resque::TermException
      Resque.enqueue(self, voter_list_id, email, cursor, results.try(:to_json))
    end
  end
  
  def self.mailer(email, voter_list)
    VoterListMailer.new(email, voter_list)
  end
end
