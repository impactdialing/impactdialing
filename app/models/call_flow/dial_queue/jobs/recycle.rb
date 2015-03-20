require 'librato_resque'
require 'impact_platform'

module CallFlow::DialQueue::Jobs
  class Recycle
    @queue = :background_worker
    extend LibratoResque

    def self.perform
      Bugsnag.before_notify_callbacks << lambda {|notification|
        msg = "DEBUG BUGSNAG (bg wrk): #{notification.inspect}"
        Rails.logger.error msg
        puts msg
      }

      raise "Testing Bugsnag notifications"

      # 2 weeks is a long time but there are currently no restrictions on Campaign#recycle_rate
      # if the campaign is created via API or the form is hacked then recycle rate could be > 72 hours
      # 2014 (w/ mid-term election) saw total of 1103 different campaigns though so 
      # loading caller sessions from the last 2 weeks won't return many distinct campaigns
      CallerSession.where('created_at > ?', 2.weeks.ago).select('DISTINCT caller_sessions.campaign_id').includes(:campaign).find_in_batches do |caller_sessions|
        caller_sessions.each do |caller_session|
          campaign   = caller_session.campaign
          dial_queue = CallFlow::DialQueue.new(campaign)
          stale      = dial_queue.available.presented_and_stale

          stale.each do |scored_phone|
            score     = scored_phone.last
            phone     = scored_phone.first
            household = campaign.households.find_by_phone(phone)
            
            if household.present?
              household.update_attributes({
                presented_at: Time.at(score)
              })
              dial_queue.dialed(household)
            end
          end

          dial_queue.recycle!
        end
      end

      # Clear the callbacks
      Bugsnag.before_notify_callbacks.clear
    end
  end
end
