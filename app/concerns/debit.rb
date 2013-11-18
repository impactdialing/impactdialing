class Debit
  attr_reader :account, :call_time, :subscription

  def initialize(call_time, account, subscription=nil)
    @call_time = call_time
    @account = account
    @subscription = subscription
  end

  def process
    if skip_debit?
      call_time.debited = true
      alert_if_missing_subscription
    else
      call_time.debited = subscription.debit(minutes)
    end
    return call_time
  end

private

  def skip_debit?
    subscription.nil?
  end

  def minutes
    (call_time.tDuration.to_f/60).ceil
  end

  def alert_if_missing_subscription
    if subscription.nil?
      subject = "nil debitable subscription"
      msg = "Account[#{account.id}]\n#{call_time.class}[#{call_time.id}]\nMinutes: #{minutes}"
      UserMailer.new.alert_email(subject, msg)
    end
  end
end
