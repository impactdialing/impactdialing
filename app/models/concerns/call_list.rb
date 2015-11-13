class CallList
  attr_reader :campaign, :stats

  # todo: encapsulate CallList::Stats here

  def initialize(campaign)
    CallFlow::DialQueue.validate_campaign!(campaign)

    @campaign = campaign
    @stats    = CallList::Stats.new(campaign)
  end

  def custom_id_register_key_base
    "list:#{campaign.id}:custom_ids"
  end

  def custom_id_register_key(custom_id)
    custom_id = custom_id.to_s
    key = custom_id_register_key_base
    if custom_id.size > 3
      key_stop = custom_id.size - 3 - 1
      key = "#{key}:#{custom_id[0..key_stop]}"
    end
    key
  end

  def custom_id_register_hash_key(custom_id)
    custom_id = custom_id.to_s
    if custom_id.size > 3
      key_start = custom_id.size - 3
      custom_id[key_start..-1]
    else
      custom_id
    end
  end
end
