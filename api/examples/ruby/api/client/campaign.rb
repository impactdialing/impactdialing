class ImpactDialing::Api::Client::Campaign < OpenStruct
  include ImpactDialing::Api::Client::Resource

  def self.create(campaign_params)
    properties = Campaigns.create(campaign_params)
    return self.new(properties)
  end

  def path
    "/client/campaigns/#{id}.json"
  end

  def voter_lists
    @voter_lists ||= VoterLists.new(self.id)
  end
end
