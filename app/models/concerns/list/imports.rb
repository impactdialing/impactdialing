# todo: unit tests
# todo: refactor:
#       - batch streaming -> AmazonS3
#       - parsing (header & rows)
# todo: fillout stats tracking
class List::Imports
  attr_reader :batch_size, :voter_list, :csv_mapping, :cursor, :results

private
  def csv_options
    {col_sep: voter_list.separator}
  end

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

  def parse_headers(line)
    row              = CSV.parse_line(line, csv_options)
    row.each_with_index do |header,i|
      @phone_index              = i if csv_mapping.mapping[header] == 'phone'
      @header_index_map[header] = i
    end
  end

  def read_file(&block)
    s3    = AmazonS3.new
    lines = []

    # todo: handle stream disruption (timeouts => retry, ghosts => you know who to call)
    # todo: handle stream pickup & process continuation
    s3.stream(voter_list.s3path) do |chunk|
      chunk.each_line{|line| lines << line}

      if lines.size >= batch_size
        yield lines
        lines = []
      end
    end
    if lines.size > 0
      yield lines
      lines = []
    end
  end

  def redis_key(phone)
    voter_list.campaign.dial_queue.households.key(phone)
  end

  def redis_stats_key
    "dial_queue:#{voter_list.campaign_id}:stats"
  end

  # return true when desirable to not import numbers for cell devices
  # return false when desirable to import numbers for both cell & landline devices
  def skip_wireless?
    voter_list.skip_wireless?
  end

  def blocked_numbers
    @blocked_numbers ||= voter_list.campaign.blocked_numbers
  end

  def dnc_wireless
    @dnc_wireless ||= DoNotCall::WirelessList.new
  end

  def calculate_blocked(phone)
    blocked = []
    if skip_wireless? && dnc_wireless.prohibits?(phone)
      blocked << :cell
      result[:cell_numbers] << phone
    end
    if blocked_numbers.include?(phone)
      blocked << :dnc
      result[:dnc_numbers] << phone
    end
    blocked
  end

  def phone_valid?(phone, csv_row)
    return true if PhoneNumber.valid?(phone)

    result[:invalid_numbers] << phone
    result[:invalid_rows]    << CSV.generate_line(csv_row.to_a)
    false
  end

  def parse_lines(lines)
    keys       = []
    households = {}
    uuid       = UUID.new
    rows       = CSV.new(lines, csv_options)
    rows.each_with_index do |row, i|
      raw_phone             = row[@phone_index]
      phone                 = PhoneNumber.sanitize(raw_phone)

      next unless phone_valid?(phone, row)

      key                   = redis_key(phone)
      lead                  = {}
      household             = {}
      lead = {
        'uuid'          => uuid.generate,
        'voter_list_id' => voter_list.id,
        'account_id'    => voter_list.account_id,
        'campaign_id'   => voter_list.campaign_id,
        'enabled'       => Voter.bitmask_for_enabled(:list),
        'phone'         => phone
      }

      csv_mapping.mapping.each do |header,attr|
        lead[attr] = row[ @header_index_map[header] ] unless @header_index_map[header] == @phone_index
      end

      households[phone] ||= {
        'leads'       => [],
        'uuid'        => uuid.generate,
        'account_id'  => voter_list.account_id,
        'campaign_id' => voter_list.campaign_id,
        'phone'       => phone,
        'blocked'     => Household.bitmask_for_blocked( *calculate_blocked(phone) )
      }

      lead['household_uuid'] = households[phone]['uuid']

      households[phone]['leads'] << lead
      keys                       << key
    end

    [keys, households]
  end
  
public
  def initialize(voter_list, cursor=0, results=nil)
    @batch_size       = (ENV['VOTER_BATCH_SIZE'] || 100).to_i
    @voter_list       = voter_list
    @csv_mapping      = CsvMapping.new(voter_list.csv_to_system_map)
    @cursor           = cursor
    @results          = setup_or_recover_results(results)

    # set from parse_headers
    @header_index_map = {}
    @phone_index      = nil
  end

  def parse(&block)
    i = 0
    read_file do |lines|
      if i.zero?
        parse_headers(lines.shift)
        i += 1
      end

      keys, households = parse_lines(lines.join)
      yield keys, households
    end
  end

  def save(redis_keys, households)
    key_base = redis_keys.first.split(':')[0..-2].join(':')
    Wolverine.dial_queue.imports(keys: [redis_stats_key] + redis_keys, argv: [key_base, households.to_json])
  end
end
