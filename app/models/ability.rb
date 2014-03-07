class Ability
  include CanCan::Ability

  attr_reader :account

  def initialize(account)
    @account = account
    apply_feature_permissions
    apply_quota_permissions
  end

  def apply_quota_permissions
    plan  = account.billing_subscription.plan
    quota = account.quota

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
