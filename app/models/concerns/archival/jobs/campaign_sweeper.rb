module Archival::Jobs
  class CampaignSweeper
    extend LibratoResque
    @queue = :general

    def self.time_threshold
      (ENV['CAMPAIGN_EXPIRY'].try(:to_i) || 90).days.ago.beginning_of_day
    end

    def self.perform
      recently_called_campaign_ids = CallAttempt.where('created_at > ?', time_threshold).select('DISTINCT(campaign_id)').pluck(:campaign_id)

      Campaign.where(active: true).
        where('updated_at < ?', time_threshold).
        where('id NOT IN (?)', recently_called_campaign_ids.uniq).
        find_in_batches(batch_size: 500) do |inactive_campaigns|
          inactive_campaigns.each do |campaign|
            campaign.active = false

            unless campaign.save(validate: false)
              extra = "ac-#{campaign.account_id}.ca-#{campaign.id}"
              ImpactPlatform::Metrics.count('job_status.invalid_record', 1, source(extra))
            end
          end
        end
    end
  end
end
