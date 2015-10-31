class CallList::Prune::Numbers
  attr_reader :voter_list

  def initialize(voter_list)
    @voter_list = voter_list
  end

  def dial_queue
    @dial_queue ||= voter_list.campaign.dial_queue
  end

  def phone_number_set_keys
    [
      dial_queue.available.keys[:active],
      dial_queue.available.keys[:presented],
      dial_queue.completed.keys[:completed],
      dial_queue.completed.keys[:failed],
      dial_queue.blocked.keys[:blocked],
      dial_queue.recycle_bin.keys[:bin],
      voter_list.stats.key,
      voter_list.campaign.call_list.stats.key
    ]
  end

  def household_hash_keys(numbers)
    redis_keys = []
    hash_keys  = []
    numbers.map do |phone|
      keys = dial_queue.households.hkey(phone)
      redis_keys << keys.first
      hash_keys << keys.last
    end
    [redis_keys, hash_keys]
  end

  def delete(numbers)
    removed_count = 0
    numbers.each_slice(50) do |batch|
      removed_count += delete_from_sets(batch)
      delete_from_hashes(batch)
    end

    return removed_count
  end

  def delete_from_sets(numbers)
    Wolverine.list.delete_numbers({
      keys: phone_number_set_keys,
      argv: [numbers.to_json]
    })
  end

  def delete_from_hashes(numbers)
    redis_keys, hash_keys = *household_hash_keys(numbers)
    Wolverine.list.delete_households({
      keys: redis_keys,
      argv: [hash_keys.to_json]
    })
  end
end

