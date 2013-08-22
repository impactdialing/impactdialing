class Ability
  include CanCan::Ability

  def initialize(account)
    can :add_transfer, Script if !account.current_subscription.transfer_types.empty?
    can :manage_caller_groups, Account if account.current_subscription.caller_groups_enabled?
    can :view_campaign_reports, Account if account.current_subscription.campaign_reports_enabled?
    can :view_caller_reports, Account if account.current_subscription.caller_reports_enabled?
    can :view_dashboard, Account if account.current_subscription.dashboard_enabled?
    can :record_calls, Account if account.current_subscription.call_recording_enabled?

    # Define abilities for the passed in user here. For example:
    #
    #   user ||= User.new # guest user (not logged in)
    #   if user.admin?
    #     can :manage, :all
    #   else
    #     can :read, :all
    #   end
    #
    # The first argument to `can` is the action you are giving the user
    # permission to do.
    # If you pass :manage it will apply to every action. Other common actions
    # here are :read, :create, :update and :destroy.
    #
    # The second argument is the resource the user can perform the action on.
    # If you pass :all it will apply to every resource. Otherwise pass a Ruby
    # class of the resource.
    #
    # The third argument is an optional hash of conditions to further filter the
    # objects.
    # For example, here the user can only update published articles.
    #
    #   can :update, Article, :published => true
    #
    # See the wiki for details:
    # https://github.com/ryanb/cancan/wiki/Defining-Abilities
  end
end
