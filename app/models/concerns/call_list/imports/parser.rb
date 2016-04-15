class CallList::Imports::Parser < CallList::Parser
private
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

  def calculate_blocked(phone, csv_row)
    blocked = []
    if skip_wireless? && dnc_wireless.prohibits?(phone)
      blocked                << :cell
      results[:cell_numbers] << phone
      cell_row!(csv_row)
    end
    if blocked_numbers.include?(phone)
      blocked               << :dnc
      results[:dnc_numbers] << phone
    end
    blocked
  end

public
  def build_household(uuid, phone, csv_row)
    {
      'leads'       => [],
      # note: imports.lua takes care to not overwrite uuid for existing households
      # so generating uuid here is safe even if phone number appears in multiple batches
      'uuid'        => uuid.generate,
      'account_id'  => voter_list.account_id,
      'campaign_id' => voter_list.campaign_id,
      'phone'       => phone,
      'blocked'     => Household.bitmask_for_blocked( *calculate_blocked(phone, csv_row) )
    }
  end

  def build_lead(uuid, phone, row, batch_index)
    lead = {}
    # populate lead w/ mapped csv data
    csv_mapping.mapping.each do |header,attr|
      next if header == VoterList::BLANK_HEADER

      attri = @header_index_map[header]
      if attri.nil?
        raise ArgumentError, "[CallList::Imports::Parser] Unable to locate index of field. Header[#{header}] attri[#{attri}] attr[#{attr}] @header_index_map[#{@header_index_map}]"
      end

      value = row[ attri ]

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
    lead['line_number']   = cursor + batch_index + 1
    lead['account_id']    = voter_list.account_id
    lead['campaign_id']   = voter_list.campaign_id
    lead['enabled']       = Voter.bitmask_for_enabled(:list)
    lead['phone']         = phone

    lead
  end

  def each_batch(&block)
    uuid       = UUID.new

    parse_file do |household_keys, csv_rows, cursor, results|
      households = {}
      csv_rows.each do |data|
        phone, csv_row, i = *data

        # aggregate leads by phone
        households[phone] ||= build_household(uuid, phone, csv_row)
        lead                = build_lead(uuid, phone, csv_row, i)

        if voter_list.maps_custom_id? and lead['custom_id'].present?
          household_keys << redis_custom_id_register_key(lead['custom_id'])
        end

        households[phone]['leads'] << lead
      end

      yield household_keys.uniq, households, cursor, results
    end
  end
end
