class CallFlow::DialQueue::Blocked < CallFlow::DialQueue::PhoneNumberSet
  attr_reader :campaign

  include CallFlow::DialQueue::Util
  include CallFlow::DialQueue::SortedSetScore

public
  def keys
    {
      blocked: "dial_queue:#{campaign.id}:blocked"
    }
  end
end
