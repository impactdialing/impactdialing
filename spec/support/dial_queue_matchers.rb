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
    "expected to find #{expected_leads} in households:#{campaign_id}:#{namespace}\nfound only these #{leads_in_redis}" 
  end
  failure_message_when_negated do |households|
    "expected to not find #{expected_leads} in households:#{campaign_id}:#{namespace}\nfound only these #{leads_in_redis}" 
  end
end
