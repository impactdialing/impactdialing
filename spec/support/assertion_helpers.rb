module AssertionHelpers
  def retry_assertion(times=1, &block)
    yield
    #retries = 0
    #begin
    #  yield(block)
    #rescue
    #  sleep(1)
    #  retry if (retries += 1) <= times
    #end
  end
end
