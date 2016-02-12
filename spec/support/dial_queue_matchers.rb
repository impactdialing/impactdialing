RSpec::Matchers.define :be_registered_as_custom_ids do
  registered_ids = []

  match do |ids|
    redis.scan_each(match: 'list*custom_ids*') do |key|
      key_parts = key.split(':')
      if key_parts[-1] =~ /\A\d+\Z/
        _id  = key_parts[-1]
        _reg = redis.hgetall(key)
        registered_ids += _reg.keys.map{|k| "#{_id}#{k}"}
      else
        registered = redis.hgetall(key)
        registered_ids += registered.keys
      end
      registered_ids.uniq!
    end

    ids.all?{|id| registered_ids.include?(id)}
  end
end

# expect(ids).to belong_to_active_leads
RSpec::Matchers.define :belong_to_active_leads do
  found_leads    = {}
  houses_in_redis = []
  lead_ids = []

  match do |ids|
    redis.scan_each(match: 'dial_queue:*:households:active:*') do |key|
      houses = redis.hgetall(key)
      houses.each do |phone_suffix, house_json|
        house = JSON.parse(house_json)
        house['leads'].each{|lead| lead_ids << lead['custom_id']}

        found = lead_ids.detect{|id| ids.include?(id)}
        if found
          found_leads[house['phone']] ||= []
          found_leads[house['phone']] << found['custom_id']
        end
        houses_in_redis << house
      end
    end

    ids.all?{|id| lead_ids.include?(id)}
  end
end

RSpec::Matchers.define :have_leads_from do |voter_list|
  expected_leads = []
  leads_in_redis = []

  match do |households|
    households.each do |phone, household|
      expected_leads += household[:leads].select{|lead| lead[:voter_list_id] == voter_list.id}.map(&:stringify_keys)
      leads_in_redis += @household_from_redis['leads']
    end
    expected_leads.all? do |expected_lead|
      leads_in_redis.include?(expected_lead)
    end
  end
  chain :in_redis_households do |campaign_id, namespace|
    key = "dial_queue:#{campaign_id}:households:#{namespace}:#{phone[0..-4]}"
    json = redis.hget(key, phone[-3..-1])
    if json.nil?
      next
    end
    @household_from_redis = JSON.parse(json)
  end
  failure_message do |households|
    "expected to find #{expected_leads} in #{campaign_id}:households:#{namespace}\nfound only these #{leads_in_redis}" 
  end
  failure_message_when_negated do |households|
    "expected to not find #{expected_leads} in #{campaign_id}:households:#{namespace}\nfound only these #{leads_in_redis}" 
  end
end

RSpec::Matchers.define :have_household_at do |campaign_id, namespace|
  key              = nil
  stored_household = nil

  match do |phone|
    key              = "dial_queue:#{campaign_id}:households:#{namespace}:#{phone[0..-4]}"
    stored_household = redis.hget(key, phone[-3..-1])
    stored_household.present?
  end

  failure_message do |phone|
    "expected #{phone} to have a household at #{key}\ngot: #{stored_household}"
  end

  failure_message_when_negated do |phone|
    "expected #{phone} to not have a household at #{key}\ngot: #{stored_household}"
  end
end

RSpec::Matchers.define :be_in_redis_households do |campaign_id, namespace|
  expected_leads           = []
  leads_in_redis           = []
  attrs_in_redis           = {}
  expected_attrs           = {}
  expected_household_attrs = %w(blocked uuid)
  attrs_match              = false
  leads_match              = false

  match do |households|
    households.each do |phone, household|
      expected_leads += household[:leads].map!(&:stringify_keys)
      key = "dial_queue:#{campaign_id}:households:#{namespace}:#{phone[0..-4]}"
      retries = 0
      begin
        json = redis.hget(key, phone[-3..-1])
      rescue SocketError => e
        p "#{e.class}: Try[#{retries}] #{e.message}"
        print e.backtrace.join("\n") + "\n"
        if retries < 10
          retries += 1
          retry
        end
        retry if retries < 10
      end
      if json.nil?
        next
      end
      _household = JSON.parse(json)

      attrs_in_redis[phone] ||= {}
      expected_attrs[phone] ||= {}
      expected_household_attrs.each do |attr|
        expected_attrs[phone][attr] = household[attr.to_sym]
        attrs_in_redis[phone][attr] = _household[attr]
      end

      leads_in_redis += _household['leads']
    end

    attrs_match = (attrs_in_redis == expected_attrs)

    leads_match = expected_leads.all? do |expected_lead|
      leads_in_redis.include?(expected_lead)
    end

    attrs_match and leads_match
  end
  failure_message do |households|
    if !leads_match
      "expected to find #{expected_leads} in #{campaign_id}:households:#{namespace}\nfound only these #{leads_in_redis}" 
    end
    if !attrs_match
      "expected household to have attributes matching: #{expected_attrs}\ngot: #{attrs_in_redis}"
    end
    "expected to find #{households} in #{campaign_id}:households:#{namespace}\nfound only #{attrs_in_redis} and #{leads_in_redis}"
  end
  failure_message_when_negated do |households|
    if !leads_match
      "expected to not find #{expected_leads} in #{campaign_id}:households:#{namespace}\nfound only these #{leads_in_redis}" 
    end
    if !attrs_match
      "expected household to not have attributes matching: #{expected_attrs}\ngot: #{attrs_in_redis}"
    end
    "expected to not find #{households} in #{campaign_id}:households:#{namespace}\nfound\nHousehold:\n#{attrs_in_redis}\nLeads:\n#{leads_in_redis}"
  end
end

RSpec::Matchers.define :be_in_dial_queue_zset do |campaign_id, namespace|
  key   = "dial_queue:#{campaign_id}:#{namespace}"

  match do |phones|
    phones = [*phones]
    phones.select do |phone|
      redis.zscore(key, phone).present?
    end.any?
  end

  failure_message do |phone|
    "expected #{phone} to be in dial queue zset #{key}\ngot #{redis.zrange(key, 0, -1)}"
  end

  failure_message_when_negated do |phones|
    "expected #{phones} to not be in dial queue zset #{key}\ngot #{redis.zrange(key, 0, -1)}"
  end
end

RSpec::Matchers.define :have_zscore do |score|
  match do |phone|
    redis.zscore(@key, phone).to_i == score.to_i
  end

  chain :in_dial_queue_zset do |campaign_id, namespace|
    @key = "dial_queue:#{campaign_id}:#{namespace}"
  end
  failure_message do |phone|
    "expected #{phone} to have zscore #{score} in #{@key} zset\ngot #{redis.zscore(@key, phone)}"
  end
end

