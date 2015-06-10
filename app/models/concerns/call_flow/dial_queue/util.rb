module CallFlow::DialQueue::Util
private
  def redis
    $redis_call_flow_connection
  end
end
