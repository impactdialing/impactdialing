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
class CallList::Jobs::Import < CallList::Jobs::Upload

  @queue = :import

  def self.args_to_requeue
    [self, *@args_to_requeue]
  end

  def self.perform_actual(voter_list_id, email=nil, cursor=0, results=nil)
    @args_to_requeue = [voter_list_id, email, cursor || 0, results.try(:to_json)]

    voter_list  = VoterList.includes(:campaign).find(voter_list_id)
    imports     = CallList::Imports.new(voter_list, cursor, results)
    imports.create_new_custom_voter_fields!

    imports.parse do |redis_keys, households|
      # debugging nil key: #104590114
      unless households.empty?
        imports.save(redis_keys, households)
      else
        pre = "[CallList::Jobs::Import]" 
        p "#{pre} Error saving households. Yielded households were empty."
        p "#{pre} Redis keys: #{redis_keys}"
        p "#{pre} Households: #{households}"
        p "#{pre} Cursor: #{imports.cursor}"
      end
      cursor  = imports.cursor
      results = imports.results

      @args_to_requeue = [voter_list_id, email, cursor, results.try(:to_json)]
    end

    # list/import.lua adds available numbers to pending during processing
    # this ensures that a household is not presented
    # until all related leads from same list have been collected
    imports.move_pending_to_available

    final_results = imports.final_results

    mailer(voter_list, email).try(:completed, final_results)
  end
end

