# todo: refactor:
#       - batch streaming -> AmazonS3
# todo: fillout stats tracking
class CallList::Imports
  attr_reader :voter_list, :cursor, :results

  include CallList::Upload::Results

private
  def default_results
    HashWithIndifferentAccess.new({
      use_custom_id:        false,
      total_rows:           0,
      saved_numbers:        0,
      total_numbers:        0,
      saved_leads:          0,
      total_leads:          0,
      new_leads:            0,
      updated_leads:        0,
      new_numbers:          0,
      pre_existing_numbers: 0,
      dnc_numbers:          Set.new,
      cell_numbers:         Set.new,
      invalid_numbers:      [],
      invalid_custom_ids:   0,
      invalid_formats:      0,
      invalid_rows:         [],
      invalid_lines:        [],
      cell_rows:            []
    })
  end

  def setup_or_recover_results(results)
    return default_results unless results

    _results = HashWithIndifferentAccess.new(JSON.parse(results))
    [
      :dnc_numbers, :cell_numbers, :invalid_numbers
    ].each do |set_name|
      _results[set_name] = Set.new(_results[set_name])
    end
    return _results
  end

  def lua_results_key
    common_redis_keys[1]
  end

  # warning: if the ordering here is changed then several lua scripts must be updated
  def common_redis_keys
    [
      "imports:#{voter_list.id}:pending",               # 1
      voter_list.stats.key,                             # 2
      voter_list.campaign.call_list.stats.key,          # 3
      dial_queue.available.keys[:active],               # 4
      dial_queue.recycle_bin.keys[:bin],                # 5
      dial_queue.blocked.keys[:blocked],                # 6
      dial_queue.completed.keys[:completed],            # 7
      dial_queue.households.keys[:completed_leads],     # 8
      dial_queue.households.keys[:message_drops],       # 9
      voter_list.campaign.custom_id_register_key_base,  # 10
      dial_queue.available.keys[:presented]             # 11
    ]
  end

protected
  def log(level, msg)
    Rails.logger.send(level, msg)
  end

public
  def initialize(voter_list, cursor=0, results=nil)
    @voter_list                  = voter_list
    @cursor                      = cursor
    @results                     = setup_or_recover_results(results)
    @starting_household_sequence = voter_list.campaign.household_sequence
  end

  def batch_size
    CallFlow::DialQueue.batch_size
  end

  def parse(&block)
    parser = CallList::Imports::Parser.new(voter_list, cursor, results, batch_size)
    parser.each_batch do |keys, households, _cursor, _results|
      yield keys, households

      update_results(_cursor, _results)
    end
  end

  def save(redis_keys, households)
    campaign = voter_list.campaign
    key_base = campaign.dial_queue.households.keys[:active]

    message_drop_completes = 0
    if campaign.use_recordings? and (not campaign.call_back_after_voicemail_delivery?)
      message_drop_completes = 1
    end

    options = {
        keys: common_redis_keys + redis_keys,
        argv: [
          key_base,
          @starting_household_sequence,
          message_drop_completes,
          households.to_json
        ]
      }
    
    if voter_list.campaign.using_custom_ids?
      Wolverine.list.import_with_custom_ids(options)
    else
      Wolverine.list.import(options)
    end
  end

  def create_new_custom_voter_fields!
    account                      = voter_list.account
    csv_mapping                  = voter_list.csv_to_system_map
    voter_system_field_names     = Voter.column_names + %w(uuid sequence)
    voter_field_names            = csv_mapping.values
    custom_voter_field_names     = voter_field_names.reject{|name| voter_system_field_names.include?(name)}
    existing_voter_field_names   = account.custom_voter_fields.where(name: custom_voter_field_names).pluck(:name)
    new_custom_voter_field_names = custom_voter_field_names - existing_voter_field_names
    new_custom_voter_field_names.compact.each do |name|
      next if name.blank?
      account.custom_voter_fields.create({name: name})
    end
  end

  def final_results
    list_results   = lua_results
    _final_results = super
    [
      :dnc_numbers, :cell_numbers, :invalid_numbers
    ].each do |collection_name|
      _final_results[collection_name] = _final_results[collection_name].size
    end

    _final_results[:saved_numbers] = list_results['total_numbers'].to_i
    _final_results[:saved_leads]   = list_results['total_leads'].to_i

    return _final_results
  end

  def move_pending_to_available
    # populate available zset as needed
    # Wolverine.dial_queue.import()
    redis.multi do
      redis.zunionstore common_redis_keys[3], [common_redis_keys[0], common_redis_keys[3]]
      redis.del common_redis_keys[0]
    end
  end
end

