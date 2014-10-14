module DialQueueHelpers  
  def keys
    subject.send(:keys)
  end
  def redis
    subject.send(:redis)
  end
end