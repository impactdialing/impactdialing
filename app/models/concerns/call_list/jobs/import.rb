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
      end

      # list/import.lua adds available numbers to pending during processing
      # this ensures that a household is not presented
      # until all related leads from same list have been collected
      imports.move_pending_to_available

      # tmp enable/disable support: disable any leads enabled during import
      # when using custom ids.
      if voter_list.campaign.using_custom_ids?
        voter_list.campaign.voter_lists.where('id < ?', voter_list_id).pluck(:id).each do |list_id|
          CallList::Jobs::ToggleActive.perform(list_id)
        end
      end

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

