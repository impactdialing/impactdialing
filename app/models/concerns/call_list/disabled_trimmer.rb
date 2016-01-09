class CallList::DisabledTrimmer < CallList::Imports
  attr_reader :voter_list

  def initialize(voter_list)
    @voter_list = voter_list
  end

  def enable_leads
    parser = CallList::Imports::Parser.new(voter_list, 0, default_results, batch_size)
    campaign = voter_list.campaign
    base_key = campaign.dial_queue.households.keys[:active].gsub(':active', '')

    message_drop_completes = 0
    if campaign.use_recordings? and (not campaign.call_back_after_voicemail_delivery?)
      message_drop_completes = 1
    end

    enabled_count = 0
    parser.each_batch do |keys, households, _, _|
      # debugging nil key: #104590114
      unless households.empty?
        enabled_count += Wolverine.list.enable_leads({
          keys: common_redis_keys + [campaign.dial_queue.completed.keys[:failed]] + keys,
          argv: [base_key, voter_list.id, message_drop_completes, households.to_json]
        })
      else
        pre = "[CallList::DisabledTrimmer]" 
        log :debug, "#{pre} Error enabling leads. Yielded households were empty."
        log :debug, "#{pre} Redis keys: #{keys}"
        log :debug, "#{pre} Households: #{households}"
      end
    end
    return enabled_count
  end

  def disable_leads
    parser = CallList::Imports::Parser.new(voter_list, 0, default_results, batch_size)
    base_key = voter_list.campaign.dial_queue.households.keys[:active].gsub(':active', '')
    disabled_count = 0
    parser.each_batch do |keys, households, _, _|
      # debugging nil key: #104590114
      unless households.empty?
        disabled_count += Wolverine.list.disable_leads({
          keys: common_redis_keys + keys,
          argv: [base_key, voter_list.id, households.to_json]
        })
      else
        pre = "[CallList::DisabledTrimmer]" 
        log :debug, "#{pre} Error disabling leads. Yielded households were empty."
        log :debug, "#{pre} Redis keys: #{keys}"
        log :debug, "#{pre} Households: #{households}"
      end
    end
    return disabled_count
  end
end
