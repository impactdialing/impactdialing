class List::DisabledTrimmer < List::Imports
  attr_reader :voter_list

  def initialize(voter_list)
    @voter_list = voter_list
  end

  def add_enabled_leads
    parser = List::Imports::Parser.new(voter_list, 0, default_results, batch_size)
    parser.parse_file do |keys, households, _, _|
      base_key = keys.first.split(':')[0..-2].join(':')
      Wolverine.list.add_enabled_leads({
        keys: common_redis_keys + keys,
        argv: [base_key, voter_list.id, households.to_json]
      })
    end
    move_pending_to_available
  end

  def remove_disabled_leads
    parser = List::Imports::Parser.new(voter_list, 0, default_results, batch_size)
    parser.parse_file do |keys, households, _, _|
      base_key = keys.first.split(':')[0..-2].join(':')
      Wolverine.list.remove_disabled_leads({
        keys: common_redis_keys + keys,
        argv: [base_key, voter_list.id, households.to_json]
      })
    end
  end
end
