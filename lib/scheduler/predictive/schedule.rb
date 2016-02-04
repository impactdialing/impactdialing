class Scheduler::Predictive::Schedule < Scheduler
  def campaigns_to_dial
    campaign_ids = RedisPredictiveCampaign.running_campaigns
    return campaign_ids if campaign_ids.empty?

    log :info, "fetching campaigns..."
    ::Predictive.where(id: campaign_ids)
  end

  def run
    log :info, "setting up timer..."
    @timer = every(interval) do
      log :info, "#{interval} elapsed, executing timer..."
      campaigns_to_dial.each do |campaign|
        process(campaign)
      end
    end
  end
end
