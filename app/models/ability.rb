class Ability
  include CanCan::Ability

  attr_reader :account, :plan, :quota, :minutes_available

  def initialize(account)
    @account           = account
    @quota             = account.quota
    @minutes_available = @quota.try(:minutes_available) || 0
    @plan              = account.billing_subscription.try(:plan) || ''

    return if @quota.disable_access?
    can :access_site, account

    apply_plan_permissions
    apply_feature_permissions
    apply_quota_permissions
  end

  def subscription_active?
    account.billing_subscription.active?
  end

  def calling_disabled?
    quota.disable_calling?
  end

  def apply_plan_permissions
    if account.billing_provider_customer_id.present?
      can :make_payment, Billing::Subscription

      # No sense allowing plan changes or adding of minutes
      # when payment can't be made.
      if plan == 'per_minute'
        can :add_minutes, Billing::Subscription
      end
      if plan != 'enterprise'
        can :change_plans, Billing::Subscription
      end
    end
    if plan != 'trial' && plan != 'per_minute' && plan != 'enterprise'
      can :cancel_subscription, Billing::Subscription
    end
  end

  def apply_quota_permissions
    return if calling_disabled?

    can :access_dialer, Caller

    case plan
    when 'enterprise'
      can :start_calling, Caller
      can :take_seat, Caller
    when 'per_minute'
      can :take_seat, Caller
      if quota.minutes_available? && subscription_active?
        can :start_calling, Caller
      end
    when 'business', 'pro', 'basic', 'trial'
      if quota.caller_seats_available? && subscription_active?
        can :take_seat, Caller
      end
      if quota.minutes_available? && subscription_active?
        can :start_calling, Caller
      end
    else
      # Allow nothing
      cannot :manage, :all
    end
  end

  def apply_feature_permissions
    can :view_campaign_reports, Account
    can :view_caller_reports, Account

    case plan
    when 'enterprise', 'per_minute', 'business', 'trial'
      can :add_transfer, Script
      can :manage, CallerGroup
      can :view_dashboard, Account
      can :record_calls, Account
      can :manage, [Preview, Power, Predictive]
    when 'pro'
      can :add_transfer, Script
      can :manage, CallerGroup
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
