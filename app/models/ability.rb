class Ability
  include CanCan::Ability

  attr_reader :account, :plan, :quota, :minutes_available

  def initialize(account)
    @account           = account
    @quota             = account.quota
    @minutes_available = @quota.try(:minutes_available) || 0
    @plan              = account.billing_subscription.try(:plan) || ''

    apply_feature_permissions
    apply_quota_permissions
    apply_plan_permissions
  end

  def apply_plan_permissions
    if account.billing_provider_customer_id.present?
      can :make_payment, Billing::Subscription

      # No sense allowing plan changes or adding of minutes
      # when payment can't be made.
      if plan == 'PerMinute'
        can :add_minutes, Billing::Subscription
      end
      if plan != 'PerMinute' || minutes_available.zero?
        can :change_plans, Billing::Subscription
      end
    end
    if plan != 'Trial'
      can :cancel_subscription, Billing::Subscription
    end
  end

  def apply_quota_permissions
    case plan
    when 'Enterprise', 'PerMinute'
      can :start_calling, CallerSession
    when 'Business', 'Pro', 'Basic', 'Trial'
      if quota.caller_seats_available?
        can :start_calling, CallerSession
      end
    else
      # Allow nothing
      cannot :manage, :all
    end
  end

  def apply_feature_permissions
    plan = account.billing_subscription.plan

    case plan
    when 'Enterprise', 'PerMinute', 'Business', 'Trial'
      can :add_transfer, Script
      can :manage, CallerGroup
      can :view_campaign_reports, Account
      can :view_caller_reports, Account
      can :view_dashboard, Account
      can :record_calls, Account
      can :manage, [Preview, Power, Predictive]
    when 'Pro'
      can :add_transfer, Script
      can :manage, CallerGroup
      can :view_campaign_reports, Account
      can :view_caller_reports, Account
      can :view_dashboard, Account
      can :manage, [Preview, Power, Predictive]
    when 'Basic'
      # Allow nothing
      can :manage, [Preview, Power]
    else
      # Allow nothing
      cannot :manage, :all
      can :read, :all
    end
  end
end
