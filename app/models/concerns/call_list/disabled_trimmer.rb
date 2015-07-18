class CallList::DisabledTrimmer < CallList::Imports
  attr_reader :voter_list

  def initialize(voter_list)
    @voter_list = voter_list
  end

  def enable_leads
    parser = CallList::Imports::Parser.new(voter_list, 0, default_results, batch_size)
    parser.parse_file do |keys, households, _, _|
      base_key = keys.first.split(':')[0..-3].join(':')
      Wolverine.list.enable_leads({
        keys: common_redis_keys + keys,
        argv: [base_key, voter_list.id, households.to_json]
      })
    end
    move_pending_to_available
  end

  def disable_leads
    parser = CallList::Imports::Parser.new(voter_list, 0, default_results, batch_size)
    parser.parse_file do |keys, households, _, _|
      base_key = keys.first.split(':')[0..-3].join(':')
      Wolverine.list.disable_leads({
        keys: common_redis_keys + keys,
        argv: [base_key, voter_list.id, households.to_json]
      })
    end
  end
end
