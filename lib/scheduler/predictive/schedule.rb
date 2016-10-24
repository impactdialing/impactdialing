class Scheduler::Predictive::Schedule < Scheduler
  def campaigns_to_dial
    campaign_ids = RedisPredictiveCampaign.running_campaigns
    return campaign_ids if campaign_ids.empty?

    ::Predictive.where(id: campaign_ids)
  end

  def run
    @timer = every(interval) do
      campaigns_to_dial.each do |campaign|
        process(campaign)
      end
    end
  end
end
