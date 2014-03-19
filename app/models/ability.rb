class Ability
  include CanCan::Ability

  attr_reader :account, :plan, :quota, :minutes_available

  def initialize(account)
    @account           = account
    @quota             = account.quota
    @minutes_available = @quota.try(:minutes_available) || 0
    @plan              = account.billing_subscription.try(:plan) || ''

    apply_plan_permissions
    apply_feature_permissions
    apply_quota_permissions
  end

  def subscription_active_and_calling_not_disabled?
    account.billing_subscription.active? &&
    calling_not_disabled?
  end

  def calling_not_disabled?
    not quota.disable_calling?
  end

  def apply_plan_permissions
    if account.billing_provider_customer_id.present?
      can :make_payment, Billing::Subscription

      # No sense allowing plan changes or adding of minutes
      # when payment can't be made.
      if plan == 'per_minute'
        can :add_minutes, Billing::Subscription
      end
      can :change_plans, Billing::Subscription
    end
    if plan != 'trial' && plan != 'per_minute'
      can :cancel_subscription, Billing::Subscription
    end
  end

  def apply_quota_permissions
    case plan
    when 'enterprise'
      if calling_not_disabled?
        can :start_calling, Caller
        can :dial, Caller
      end
    when 'per_minute'
      if quota.minutes_available? && subscription_active_and_calling_not_disabled?
        can :start_calling, Caller
        can :dial, Caller
      end
    when 'business', 'pro', 'basic', 'trial'
      if quota.caller_seats_available? && quota.minutes_available? && subscription_active_and_calling_not_disabled?
        can :start_calling, Caller
        can :dial, Caller
      end
    else
      # Allow nothing
      cannot :manage, :all
    end
  end

  def apply_feature_permissions
    case plan
    when 'enterprise', 'per_minute', 'business', 'trial'
      can :add_transfer, Script
      can :manage, CallerGroup
      can :view_campaign_reports, Account
      can :view_caller_reports, Account
      can :view_dashboard, Account
      can :record_calls, Account
      can :manage, [Preview, Power, Predictive]
    when 'pro'
      can :add_transfer, Script
      can :manage, CallerGroup
      can :view_campaign_reports, Account
      can :view_caller_reports, Account
      can :view_dashboard, Account
      can :manage, [Preview, Power, Predictive]
    when 'basic'
      can :manage, [Preview, Power]
    else
      # Allow nothing
      cannot :manage, :all
      can :read, :all
    end
  end
end
