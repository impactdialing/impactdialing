class CallList::Prune::Leads
  attr_reader :voter_list, :cursor, :results

  include CallList::Upload::Results

private
  def default_results
    HashWithIndifferentAccess.new({
      total_rows: 0,
      removed_leads: 0,
      removed_numbers: 0,
      total_leads: 0,
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

  def household_hash_key(phone)
    dial_queue.households.hkey(phone)
  end

  def batch_size
    50
  end

  def parse(&block)
    parser = CallList::Prune::Leads::Parser.new(voter_list, cursor,
                                                  results, batch_size)
    parser.each_batch do |phones_and_ids, _cursor, _results|
      yield phones_and_ids
      update_results(_cursor, _results)
    end
  end

  def delete(key_id_pairs)
    removed_leads   = 0
    removed_numbers = 0
    key_id_pairs.each_slice(batch_size) do |batch|
      _count, phones_to_delete = *delete_leads(batch)
      delete_phone_numbers(phones_to_delete)
    end
  end

  def final_results
    list_results = lua_results
    super.merge({
      removed_numbers: list_results['removed_numbers'].to_i,
      removed_leads: list_results['removed_leads'].to_i,
      total_numbers:   list_results['total_numbers'].to_i,
      invalid_numbers: results[:invalid_numbers].size
    })
  end

  def delete_phone_numbers(numbers)
    return 0 if numbers.empty?

    Wolverine.list.delete_numbers({
      keys: phone_number_set_keys,
      argv: [numbers.to_json]
    })
  end

  def delete_leads(key_id_pairs)
    removed_lead_count = 0
    numbers_to_delete = []
    key_id_pairs.each do |key_id_pair|
      id, register_key = *key_id_pair
      register_hkey    = voter_list.campaign.call_list.custom_id_register_hash_key(id)
      phone   = redis.hget(register_key, register_hkey)
      next if phone.blank?

      redis_key, hash_key = *household_hash_key(phone)
      _output = Wolverine.list.delete_leads({
        keys: [redis_key, register_key] + phone_number_set_keys,
        argv: [hash_key, id, register_hkey]
      })
      output = JSON.parse(_output)
      output[1] = output[1].to_a
      removed_lead_count += output[0]
      numbers_to_delete += output[1]
    end

    return [removed_lead_count, numbers_to_delete.flatten.uniq]
  end
end

