class CallList::Prune::Numbers
  attr_reader :voter_list, :cursor, :results

  include CallList::Upload::Results

private
  def default_results
    HashWithIndifferentAccess.new({
      total_rows: 0,
      removed_numbers: 0,
      total_numbers: 0,
      invalid_numbers: [],
      invalid_formats: 0,
      invalid_rows: [],
      invalid_lines: []
    })
  end

  def lua_results_key
    phone_number_set_keys[6]
  end

public
  def initialize(voter_list, cursor=0, results=nil)
    @voter_list = voter_list
    @cursor     = cursor
    @results    = setup_or_recover_results(results)
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

  def batch_size
    50
  end

  def parse(&block)
    parser = CallList::Prune::Numbers::Parser.new(voter_list, cursor,
                                                  results, batch_size)
    parser.each_batch do |numbers, _cursor, _results|
      yield numbers
      update_results(_cursor, _results)
    end
  end

  def delete(numbers)
    removed_count = 0
    numbers.each_slice(50) do |batch|
      removed_count += delete_from_sets(batch)
      delete_from_hashes(batch)
    end

    return removed_count
  end

  def final_results
    list_results = lua_results
    super.merge({
      removed_numbers: list_results['removed_numbers'].to_i,
      total_numbers:   list_results['total_numbers'].to_i,
      invalid_numbers: results[:invalid_numbers].size
    })
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

