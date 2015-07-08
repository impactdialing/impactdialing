# todo: unit tests
# todo: refactor:
#       - batch streaming -> AmazonS3
# todo: fillout stats tracking
class List::Imports
  attr_reader :voter_list, :cursor, :results

private
  def default_results
    {
      saved_numbers:        0,
      total_numbers:        0,
      saved_leads:          0,
      total_leads:          0,
      new_leads:            0,
      updated_leads:        0,
      new_numbers:          Set.new,
      pre_existing_numbers: Set.new,
      dnc_numbers:          Set.new,
      cell_numbers:         Set.new,
      invalid_numbers:      Set.new,
      invalid_rows:         [],
      use_custom_id:        false
    }
  end

  def setup_or_recover_results(results)
    return default_results unless results

    _results = HashWithIndifferentAccess.new(JSON.parse(results))
    [
      :new_numbers, :pre_existing_numbers, :dnc_numbers,
      :cell_numbers, :invalid_numbers
    ].each do |set_name|
      _results[set_name] = Set.new(_results[set_name])
    end
    return _results
  end

  def redis_stats_key
    "dial_queue:#{voter_list.campaign_id}:stats"
  end
  
public
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

      @cursor  = _cursor
      @results = _results
    end
  end

  def save(redis_keys, households)
    key_base = redis_keys.first.split(':')[0..-2].join(':')
    Wolverine.dial_queue.imports(keys: [redis_stats_key] + redis_keys, argv: [key_base, households.to_json])
  end
end
