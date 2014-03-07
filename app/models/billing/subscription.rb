class Billing::Subscription < ActiveRecord::Base
  attr_accessible :account_id, :plan, :provider_status, :provider_subscription_id

  belongs_to :account

  validates_presence_of :account, :plan

public
  def trial?
    return plan == 'Trial'
  end
end
