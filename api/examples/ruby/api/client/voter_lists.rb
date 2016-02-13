class ImpactDialing::Api::Client::VoterLists
  include ImpactDialing::Api::Client::Collection

  attr_reader :campaign_id

  def initialize(campaign_id)
    @campaign_id = campaign_id
  end

  def path
    "/client/campaigns/#{campaign_id}/voter_lists.json"
  end

  def after_create(data)
    list = OpenStruct.new data['voter_list']
    print "Uploaded List##{list.id} #{list.name}!\n"
    return list
  end

  def create(file_params, list_params)
    super(:voter_list, list_params, file_params)
  end
end
