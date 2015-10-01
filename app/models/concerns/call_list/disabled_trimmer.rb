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

    parser.parse_file do |keys, households, _, _|
      # debugging nil key: #104590114
      unless households.empty?
        Wolverine.list.enable_leads({
          keys: common_redis_keys + keys,
          argv: [base_key, voter_list.id, message_drop_completes, households.to_json]
        })
      else
        pre = "[CallList::DisabledTrimmer]" 
        p "#{pre} Error enabling leads. Yielded households were empty."
        p "#{pre} Redis keys: #{keys}"
        p "#{pre} Households: #{households}"
      end
    end
  end

  def disable_leads
    parser = CallList::Imports::Parser.new(voter_list, 0, default_results, batch_size)
    base_key = voter_list.campaign.dial_queue.households.keys[:active].gsub(':active', '')
    parser.parse_file do |keys, households, _, _|
      # debugging nil key: #104590114
      unless households.empty?
        Wolverine.list.disable_leads({
          keys: common_redis_keys + keys,
          argv: [base_key, voter_list.id, households.to_json]
        })
      else
        pre = "[CallList::DisabledTrimmer]" 
        p "#{pre} Error disabling leads. Yielded households were empty."
        p "#{pre} Redis keys: #{keys}"
        p "#{pre} Households: #{households}"
      end
    end
  end
end
