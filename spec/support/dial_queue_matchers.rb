RSpec::Matchers.define :have_leads_from do |voter_list|
  redis          = Redis.new
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

RSpec::Matchers.define :be_in_redis_households do |campaign_id, namespace|
  redis               = Redis.new
  expected_leads      = []
  leads_in_redis      = []

  match do |households|
    households.each do |phone, household|
      expected_leads += household[:leads].map!(&:stringify_keys)
      key = "dial_queue:#{campaign_id}:households:#{namespace}:#{phone[0..-4]}"
      json = redis.hget(key, phone[-3..-1])
      if json.nil?
        next
      end
      _household = JSON.parse(json)
      leads_in_redis += _household['leads']
    end
    expected_leads.all? do |expected_lead|
      leads_in_redis.include?(expected_lead)
    end
  end
  failure_message do |households|
    "expected to find #{expected_leads} in #{campaign_id}:households:#{namespace}\nfound only these #{leads_in_redis}" 
  end
  failure_message_when_negated do |households|
    "expected to not find #{expected_leads} in #{campaign_id}:households:#{namespace}\nfound only these #{leads_in_redis}" 
  end
end

RSpec::Matchers.define :be_in_dial_queue_zset do |campaign_id, namespace|
  redis = Redis.new
  key   = "dial_queue:#{campaign_id}:#{namespace}"

  match do |phone|
    redis.zscore(key, phone).present?
  end
end

RSpec::Matchers.define :have_zscore do |score|
  match do |phone|
    redis = Redis.new
    redis.zscore(@key, phone).to_s == score.to_s
  end

  chain :in_dial_queue_zset do |campaign_id, namespace|
    @key = "dial_queue:#{campaign_id}:#{namespace}"
  end
  failure_message do |phone|
    "expected #{phone} to have zscore #{score} in #{@key} zset\ngot #{redis.zscore(@key, phone)}"
  end
end

