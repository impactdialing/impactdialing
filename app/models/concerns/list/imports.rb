# todo: refactor:
#       - batch streaming -> AmazonS3
# todo: fillout stats tracking
class List::Imports
  attr_reader :voter_list, :cursor, :results

private
  def default_results
    HashWithIndifferentAccess.new({
      use_custom_id:        false,
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
      invalid_numbers:      Set.new,
      invalid_custom_ids:   0,
      invalid_rows:         []
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

  def lua_results
    redis.hgetall common_redis_keys[1]
  end

  def update_results(_cursor, _results)
    @cursor  = _cursor
    @results = _results

    lua_results.each do |key,count|
      @results[key] ||= 0
      @results[key] += count.to_i
    end
  end

  def dial_queue
    @dial_queue ||= voter_list.campaign.dial_queue
  end

  # warning: if the ordering here is changed then wolverine/list/import.lua script must be updated
  def common_redis_keys
    [
      "imports:#{voter_list.id}:pending",
      voter_list.list_stats_key,
      voter_list.campaign.list_stats_key,
      dial_queue.available.keys[:active],
      dial_queue.recycle_bin.keys[:bin],
      dial_queue.blocked.keys[:blocked],
      dial_queue.completed.keys[:completed]
    ]
  end

public
  def self.redis
    @redis ||= Redis.new
  end

  def redis
    self.class.redis
  end

  def initialize(voter_list, cursor=0, results=nil)
    @voter_list = voter_list
    @cursor     = cursor
    @results    = setup_or_recover_results(results)
  end

  def batch_size
    (ENV['VOTER_BATCH_SIZE'] || 100).to_i
  end

  def parse(&block)
    parser = List::Imports::Parser.new(voter_list, cursor, results, batch_size)
    parser.parse_file do |keys, households, _cursor, _results|
      yield keys, households

      update_results(_cursor, _results)
    end
  end

  def save(redis_keys, households)
    key_base    = redis_keys.first.split(':')[0..-2].join(':')
    
    Wolverine.list.import({
      keys: common_redis_keys + redis_keys,
      argv: [key_base, households.to_json]
    })
  end

  def final_results
    final_results = results.dup
    [
      :dnc_numbers, :cell_numbers, :invalid_numbers
    ].each do |set_name|
      final_results[set_name] = final_results[set_name].size
    end

    final_results[:saved_numbers] = final_results[:pre_existing_numbers] +
                                    final_results[:new_numbers] +
                                    final_results[:cell_numbers] +
                                    final_results[:dnc_numbers]
    final_results[:total_numbers] = final_results[:saved_numbers] +
                                    final_results[:invalid_numbers]
    final_results[:saved_leads] = final_results[:updated_leads] +
                                  final_results[:new_leads]
    final_results[:total_leads] = final_results[:saved_leads] +
                                  final_results[:invalid_custom_ids]

    return final_results
  end

  def move_pending_to_available
    # populate available zset as needed
    # Wolverine.dial_queue.import()
    Redis.new.zunionstore common_redis_keys[3], [common_redis_keys[0], common_redis_keys[3]]
  end
end
