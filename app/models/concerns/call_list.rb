class CallList
  attr_reader :campaign

  # todo: encapsulate CallList::Stats here

  def initialize(campaign)
    CallFlow::DialQueue.validate_campaign!(campaign)

    @campaign = campaign
  end

  def custom_id_register_key_base
    "list:#{campaign.id}:custom_ids"
  end

  def custom_id_register_key(custom_id)
    key = custom_id_register_key_base
    if custom_id.size > 3
      key_stop = custom_id.size - 3 - 1
      key = "#{key}:#{custom_id[0..key_stop]}"
    end
    key
  end
end
