class RedisReassignedCallerSession

  def self.set_campaign_id(caller_session_id, campaign_id)
    $redis_caller_session_uri_connection.set "reassigned_:#{caller_session_id}", campaign_id
  end

  def self.campaign_id(caller_session_id)
    $redis_caller_session_uri_connection.get "reassigned_:#{caller_session_id}"
  end

  def self.delete(caller_session_id)
    $redis_caller_session_uri_connection.del "reassigned_:#{caller_session_id}"
  end

end