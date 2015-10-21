module CallFlow
  class CallFlow::BaseArgumentError < ArgumentError; end

  def self.generate_token
    args = [Time.now, (1..10).map{ rand.to_s }]
    return TokenGenerator.sha_hexdigest(*args)
  end
end
