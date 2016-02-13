class ImpactDialing::Api::Client::Campaigns
  include ImpactDialing::Api::Client::Collection

  def path
    "/client/campaigns.json"
  end

  def after_create(data)
    campaign = ImpactDialing::Api::Client::Campaign.new data['campaign']
    print "Created Campaign##{campaign.id} #{campaign.name}!\n"
    return campaign
  end

  def create(campaign_params)
    super(:campaign, campaign_params)
  end

  def parse_json(text)
    json = JSON.parse(text)
    if json.first.kind_of? Hash
      json.map! do |item|
        Campaign.new item
      end
    end
    json
  end
end
