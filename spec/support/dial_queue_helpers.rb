module DialQueueHelpers  
  def keys
    subject.send(:keys)
  end
  def redis
    subject.respond_to?(:redis) ? subject.send(:redis) : Redis.new
  end
  # workaround race condition
  # cause unclear but related to Redis.new.flushall in before/after hooks
  def dial_queue_retry_on_trxn_fail(&block)
    retries = 0
    begin 
      yield
    rescue CallFlow::DialQueue::Available::RedisTransactionAborted
      retries += 1
      if retries < 4
        p "zpop retries: #{retries}"
        retry
      else
        raise
      end
    end
  end

  def dial_queue_pop_n_reliably(dial_queue, n)
    numbers = nil
    dial_queue_retry_on_trxn_fail do
      numbers = dial_queue.next(n)
    end
    numbers
  end
end
