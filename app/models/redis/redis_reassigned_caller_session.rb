class RedisReassignedCallerSession

  def self.redis_connection_pool
    $redis_caller_session_uri_connection
  end

  def self.set_campaign_id(caller_session_id, campaign_id)
    redis_connection_pool.with{|conn| conn.set "reassigned_:#{caller_session_id}", campaign_id}
    # $redis_caller_session_uri_connection.set "reassigned_:#{caller_session_id}", campaign_id
  end

  def self.campaign_id(caller_session_id)
    redis_connection_pool.with{|conn| conn.get "reassigned_:#{caller_session_id}"}
    # $redis_caller_session_uri_connection.get "reassigned_:#{caller_session_id}"
  end

  def self.delete(caller_session_id)
    redis_connection_pool.with{|conn| conn.del "reassigned_:#{caller_session_id}"}
    # $redis_caller_session_uri_connection.del "reassigned_:#{caller_session_id}"
  end

end