module CallStats
  def self.call_attempts(resource)
    if resource.kind_of? Campaign
      index_name = "index_call_attempts_on_campaign_id_created_at_status"
      resource.call_attempts.from("call_attempts use index (#{index_name})")
    else
      resource.call_attempts
    end
  end

  def self.all_voters(resource)
    resource.all_voters
  end

  def self.between(query, from_date=nil, to_date=nil)
    return query if from_date.nil? or to_date.nil?
    query.between(from_date, to_date)
  end
end