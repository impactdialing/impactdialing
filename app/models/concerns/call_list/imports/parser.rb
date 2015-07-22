class CallList::Imports::Parser
  attr_reader :voter_list, :csv_mapping, :results, :batch_size, :cursor

private
  def csv_options
    {col_sep: voter_list.separator}
  end

  def redis_key(phone)
    voter_list.campaign.dial_queue.households.key(phone)
  end

  def redis_custom_id_register_key(custom_id)
    voter_list.campaign.call_list.custom_id_register_key(custom_id)
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
      blocked                << :cell
      results[:cell_numbers] << phone
    end
    if blocked_numbers.include?(phone)
      blocked               << :dnc
      results[:dnc_numbers] << phone
    end
    blocked
  end

  def invalid_row!(csv_row)
    results[:invalid_rows] << CSV.generate_line(csv_row.to_a)
  end

  def invalid_custom_id!(csv_row)
    results[:invalid_custom_ids] += 1
    invalid_row!(csv_row)
  end

  def invalid_phone!(phone, csv_row)
    results[:invalid_numbers] << phone
    invalid_row!(csv_row)
  end

  def phone_valid?(phone, csv_row)
    unless PhoneNumber.valid?(phone)
      invalid_phone!(phone, csv_row)
      return false
    end

    true
  end

  def read_file(&block)
    s3           = AmazonS3.new
    lines        = []
    partial_line = nil

    # todo: handle stream disruption (timeouts => retry, ghosts => you know who to call)
    # todo: handle stream pickup & process continuation
    s3.stream(voter_list.s3path) do |chunk|
      chunk.each_line{|line| lines << line}

      unless partial_line.nil?
        # first line of this chunk is last part of current partial_line
        last_part = lines.shift
        whole_part = "#{partial_line}#{last_part}"
        lines.unshift whole_part
        partial_line = nil
      end

      if lines.last !~ /#{$/}\Z/
        # last line doesn't have newline character
        partial_line = lines.pop
      end

      if lines.size >= batch_size
        yield lines
        lines = []
      end
    end

    yield lines if lines.size > 0
  end

public
  def initialize(voter_list, cursor, results, batch_size)
    @voter_list              = voter_list
    @csv_mapping             = CsvMapping.new(voter_list.csv_to_system_map)
    @batch_size              = batch_size
    @cursor                  = cursor
    @results                 = results
    @results[:use_custom_id] = @csv_mapping.use_custom_id?

    # set from parse_headers
    @header_index_map = {}
    @phone_index      = nil
  end

  def parse_file(&block)
    i = 0
    start_at = nil

    if @cursor > 0
      # continue from previous position
      start_at = @cursor
    end

    read_file do |lines|
      if i.zero?
        parse_headers(lines.shift)
        i     += 1
        @cursor = i
      end

      unless start_at.nil?
        @cursor += lines.size

        if start_at <= cursor
          lines = lines[start_at-@cursor..-1]
          start_at = nil
        else
          next
        end
      end

      keys, households = parse_lines(lines.join)

      p "@cursor = #{@cursor}"
      p "cursor = #{cursor}"
      @cursor += lines.size

      yield keys, households, @cursor, results
    end
  end

  def parse_headers(line)
    row              = CSV.parse_line(line, csv_options)
    row.each_with_index do |header,i|
      @phone_index              = i if csv_mapping.mapping[header] == 'phone'
      @header_index_map[header] = i
    end
  end

  def build_household(uuid, phone)
    {
      'leads'       => [],
      # note: imports.lua takes care to not overwrite uuid for existing households
      # so generating uuid here is safe even if phone number appears in multiple batches
      'uuid'        => uuid.generate,
      'account_id'  => voter_list.account_id,
      'campaign_id' => voter_list.campaign_id,
      'phone'       => phone,
      'blocked'     => Household.bitmask_for_blocked( *calculate_blocked(phone) )
    }
  end

  def build_lead(uuid, phone, row, batch_index, batch_count)
    lead = {}
    # populate lead w/ mapped csv data
    csv_mapping.mapping.each do |header,attr|
      value = row[ @header_index_map[header] ]

      if value.blank? or attr.blank?
        if attr == 'custom_id'
          # custom_id is a blank value => invalid
          invalid_custom_id!(row)
        end

        # skip blank values
        next
      end
      
      lead[attr] = value
    end

    # now build lead w/ system data
    # this needs to happen after csv values are set
    # in case csv values define things they shouldn't, eg account_id, etc
    #
    # note: imports.lua takes care to not overwrite uuid for existing leads
    # so generating here is safe even if lead w/ same custom id appears in multiple batches
    lead['uuid']          = uuid.generate
    lead['voter_list_id'] = voter_list.id
    lead['line_number']   = (cursor - batch_count) + batch_index + 1
    lead['account_id']    = voter_list.account_id
    lead['campaign_id']   = voter_list.campaign_id
    lead['enabled']       = Voter.bitmask_for_enabled(:list)
    lead['phone']         = phone

    lead
  end

  def parse_lines(lines)
    keys       = []
    households = {}
    line_count = lines.size
    uuid       = UUID.new
    rows       = CSV.new(lines, csv_options)
    rows.each_with_index do |row, i|
      raw_phone             = row[@phone_index]
      phone                 = PhoneNumber.sanitize(raw_phone)

      next unless phone_valid?(phone, row)

      # aggregate leads by phone
      households[phone] ||= build_household(uuid, phone)
      lead                = build_lead(uuid, phone, row, i, line_count)

      households[phone]['leads'] << lead
      # build keys here to maintain cluster support
      keys                       << redis_key(phone)

      if voter_list.maps_custom_id? and lead['custom_id'].present?
        # key order doesn't matter, lua script should re-assemble keys as needed
        keys << redis_custom_id_register_key(lead['custom_id']) 
      end
    end

    [keys.uniq, households]
  end
end
