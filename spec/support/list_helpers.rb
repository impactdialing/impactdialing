class Forgery::Address < Forgery
  def self.clean_phone
    formats[:clean_phone].random.to_numbers
  end
end

module ListHelpers
  def import_list(list, households, household_namespace='active', zset_namespace='active')
    base_key = "dial_queue:#{list.campaign_id}:households:#{household_namespace}"
    sequence = 1
    lead_sequence = "#{sequence}0".to_i
    households.each do |phone, household|
      household['sequence'] = sequence
      leads = []
      household[:leads].each do |lead|
        lead['sequence'] = lead_sequence

        if lead[:custom_id].present?
          lead[:custom_id] = lead_sequence.to_s
          key = list.campaign.call_list.custom_id_register_key(lead[:custom_id])
          hkey = lead[:custom_id].size > 3 ? lead[:custom_id][-4..-1] : lead[:custom_id]
          redis.hset(key, hkey, phone)
        end

        redis.hincrby list.campaign.call_list.stats.key, 'total_leads', 1
        redis.hincrby list.stats.key, 'total_leads', 1
        leads << lead
        lead_sequence += 1
      end
      household[:leads] = leads
      key = "#{base_key}:#{phone[0..ENV['REDIS_PHONE_KEY_INDEX_STOP'].to_i]}"
      hkey = phone[ENV['REDIS_PHONE_KEY_INDEX_STOP'].to_i + 1..-1]
      redis.hincrby list.campaign.call_list.stats.key, 'total_numbers', 1
      redis.hincrby list.stats.key, 'total_numbers', 1
      redis.hset key, hkey, household.to_json
      redis.zadd "dial_queue:#{list.campaign_id}:#{zset_namespace}", zscore(sequence), phone 
      sequence += 1
    end
  end

  def add_leads(list, phone, leads, household_namespace='active', zset_namespace='active')
    lead_sequence = 1
    lds = []
    leads.each do |lead|
      lead['sequence'] = lead_sequence
      lead_sequence += 1
      lds << lead
    end
    leads = lds
    base_key = "dial_queue:#{list.campaign_id}:households:#{household_namespace}"
    key = "#{base_key}:#{phone[0..ENV['REDIS_PHONE_KEY_INDEX_STOP'].to_i]}"
    hkey = phone[ENV['REDIS_PHONE_KEY_INDEX_STOP'].to_i + 1..-1]
    current_household = JSON.parse(redis.hget(key, hkey))
    current_household['leads'] += leads
    redis.hset(key, hkey, current_household.to_json)
  end

  def save_lead_update(list, phone, updated_leads, household_namespace='active', zset_namespace='active')
    base_key          = "dial_queue:#{list.campaign_id}:households:#{household_namespace}"
    key               = "#{base_key}:#{phone[0..ENV['REDIS_PHONE_KEY_INDEX_STOP'].to_i]}"
    hkey              = phone[ENV['REDIS_PHONE_KEY_INDEX_STOP'].to_i + 1..-1]
    current_household = JSON.parse(redis.hget(key, hkey))
    black_keys        = %w(custom_id uuid sequence sql_id)
    lds               = []
    current_household['leads'].each do |cur_lead|
      updated_lead = updated_leads.detect{|ld| ld[:custom_id] == cur_lead['custom_id']}

      updated_lead.keys.each do |key|
        cur_lead[key] = updated_lead[key] unless black_keys.include?(key.to_s)
      end
      lds << cur_lead
    end
    current_household['leads'] = lds
    redis.hset(key, hkey, current_household.to_json)
  end

  def zscore(sequence)
    Time.now.utc.to_f
  end

  def disable_list(list)
    list.update_attributes!(enabled: false)
  end

  def enable_list(list)
    list.update_attributes!(enabled: true)
  end

  def stub_list_parser(parser_double, redis_key, household)
    allow(parser_double).to receive(:each_batch).and_yield([redis_key], household, 0, {})
    allow(CallList::Imports::Parser).to receive(:new){ parser_double }
  end

  def build_household_hashes(n, list, with_custom_id=false, two_lead_min=false, with_very_long_values=false)
    h = {}
    n.times do
      h.merge!(build_household_hash(list, with_custom_id, two_lead_min, with_very_long_values))
    end
    h
  end

  def build_household_hash(list, with_custom_id=false, two_lead_min=false, with_very_long_values=false, phone=nil)
    phone ||= Forgery(:address).clean_phone
    min   = two_lead_min ? 2 : 1
    leads = build_leads_array( (min..5).to_a.sample, list, phone, with_custom_id, with_very_long_values )
    if with_custom_id
      # de-dup
      ids = []
      leads.map! do |lead|
        if ids.include? lead[:custom_id]
          nil
        else
          ids << lead[:custom_id]
          lead
        end
      end.compact!
    end
    {
      phone => {
        leads: leads,
        blocked: 0,
        uuid: "hh-uuid-#{phone}",
        score: Time.now.to_f,
        phone: phone
      }
    }
  end

  def update_leads(leads, &block)
    updated_leads = []
    leads.each do |lead|
      yield lead
      updated_leads << lead
    end
    updated_leads
  end

  def build_leads_array(n, list, phone, with_custom_id=false, with_very_long_values=false)
    a = []
    n.times do |i|
      a << build_lead_hash(list, phone, with_custom_id, with_very_long_values)
    end
    a
  end

  def build_lead_hash(list, phone, id=nil, with_very_long_value=false)
    @uuid ||= UUID.new
    h = {
      voter_list_id: list.id.to_s,
      uuid: @uuid.generate,
      phone: phone,
      first_name: Forgery(:name).first_name,
      last_name: Forgery(:name).last_name,
      email: Forgery(:internet).email_address,
      'Polling location' => 'Kansas City',
      'Party affil.' => 'I'
    }
    if with_very_long_value
      val = ''
      260.times{ val << 'abc' }
      h.merge!({
        'Very Long Value' => val
      })
    end
    if id
      custom_id = id.kind_of?(Integer) ? id : Forgery(:basic).number.to_s
      h.merge!(custom_id: custom_id)
    end
    h
  end
end

