class Quota < ActiveRecord::Base
  # Help out rails...
  self.table_name = 'quotas'

  attr_accessible :account_id, :callers_allowed, :disable_calling, :minutes_allowed, :minutes_pending, :minutes_used

  belongs_to :account

  validates_presence_of :account

  ##
  # Return true if +minutes_available+ > 0,
  # false otherwise.
  #
  def minutes_available?
    return minutes_available > 0
  end

  ##
  # Return true if +minutes_pending+ > 0,
  # false otherwise.
  #
  def minutes_pending?
    return minutes_pending > 0
  end

  ##
  # Return the number of minutes remaining, calculated as
  # +minutes_allowed+ - +minutes_used+ - +minutes_pending+.
  # Never returns a number < 0 in order to keep calculations
  # simple.
  #
  # *Note:* calculations in +debit+ depend on this never
  # returning a number < 0.
  #
  def minutes_available
    n = (minutes_allowed - minutes_used - minutes_pending)
    n = 0 if n < 0
    return n
  end

  ##
  # Return true if the +callers_allowed+ quota has not been reached,
  # false otherwise.
  #
  def caller_seats_available?
    # todo: Verify there are no phantom callers
    # Perform seat check auth/z
    return callers_allowed > account.caller_seats_taken
  end

  ##
  # Add minutes_to_charge to one or both of +minutes_used+ and +minutes_pending+.
  # A background job (+ToBeNamed+) will run on some schedule to take appropriate
  # action for accounts w/ some positive number in +minutes_pending+.
  #
  def debit(minutes_to_charge)
    used    = minutes_to_charge
    pending = 0
    if minutes_to_charge > minutes_available
      used    = minutes_available
      pending = minutes_to_charge - (minutes_allowed - minutes_used)
    end
    used    += minutes_used
    pending += minutes_pending
    return update_attributes({
      minutes_used: used,
      minutes_pending: pending
    })
  end
end
