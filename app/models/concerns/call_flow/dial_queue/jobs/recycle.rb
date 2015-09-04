require 'librato_resque'

module CallFlow::DialQueue::Jobs
  class Recycle
    @queue = :dial_queue
    extend LibratoResque

    def self.perform
      processed = []
      by_caller_session do |campaign|
        dial_queue = CallFlow::DialQueue.new(campaign)
        recycle(dial_queue)
        processed << campaign.id
      end

      by_updated(processed) do |campaign|
        dial_queue = CallFlow::DialQueue.new(campaign)
        recycle(dial_queue)
      end
    end

private
    def self.recycle(dial_queue)
      stale = dial_queue.available.presented_and_stale

      if stale.any?
        dial_queue.available.insert(stale.map(&:reverse))
      end

      dial_queue.recycle!
    end

    def self.by_caller_session(&block)
      # 2 weeks is a long time but there are currently no restrictions on Campaign#recycle_rate
      # if the campaign is created via API or the form is hacked then recycle rate could be > 72 hours
      # 2014 (w/ mid-term election) saw total of 1103 different campaigns though so 
      # loading caller sessions from the last 2 weeks won't return many distinct campaigns
      processed = []
      ::CallerSession.where('created_at > ?', 2.weeks.ago).select('DISTINCT caller_sessions.campaign_id, caller_sessions.id').includes(:campaign).find_in_batches do |caller_sessions|
        caller_sessions.each do |caller_session|
          next if processed.include? caller_session.campaign.id
          yield caller_session.campaign
          processed << caller_session.campaign.id
        end
      end
    end

    def self.by_updated(processed, &block)
      Campaign.where('id NOT IN (?)', processed).where('updated_at > ?', 30.days.ago).find_in_batches do |campaigns|
        campaigns.each do |campaign|
          yield campaign
        end
      end
    end
  end
end

