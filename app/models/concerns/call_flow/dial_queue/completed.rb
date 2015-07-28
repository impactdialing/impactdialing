class CallFlow::DialQueue::Completed < CallFlow::DialQueue::PhoneNumberSet
  attr_reader :campaign

  include CallFlow::DialQueue::Util
  include CallFlow::DialQueue::SortedSetScore

public
  def keys
    {
      completed: "dial_queue:#{campaign.id}:completed",
      failed: "dial_queue:#{campaign.id}:failed"
    }
  end
end
