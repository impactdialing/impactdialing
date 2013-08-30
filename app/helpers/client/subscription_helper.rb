module Client::SubscriptionHelper
  def subscription_type_options_for_select
    Subscription::Type::PAID_SUBSCRIPTIONS.map do |type|
      [type.underscore.humanize, type]
    end
  end
end