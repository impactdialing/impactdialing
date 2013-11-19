module RescueRetryNotify
  def self.on(exception_class, limit, &block)
    raise ArgumentError, 'A block is required' if not block_given?

    attempts = []
    begin
      start = Time.now

      yield
    rescue exception_class => e
      stop = Time.now
      diff = stop - start
      attempts << diff
      if attempts.size < limit
        retry
      else
        msg = "#{attempts.size} attempts made:<br/>#{attempts.join('<br/>')}<br/>"
        UserMailer.new.deliver_exception_notification(msg, e)
        raise e
      end
    end
  end
end