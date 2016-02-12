module DialQueueHelpers  
  def keys
    subject.send(:keys)
  end
  # workaround race condition
  # cause unclear but related to Redis.new.flushall in before/after hooks
  def dial_queue_retry_on_trxn_fail(&block)
    yield
  end

  def dial_queue_pop_n_reliably(dial_queue, n)
    numbers = nil
    dial_queue_retry_on_trxn_fail do
      numbers = dial_queue.next(n)
    end
    numbers
  end
end
