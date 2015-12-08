module RedisFactories
  def redis_status_set_state(*args)
    campaign, state, caller_session  = *args
    RedisStatus.set_state_changed_time(campaign, state, caller_session)
  end
end
