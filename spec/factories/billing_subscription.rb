FactoryGirl.define do
  factory :bare_subscription, class: 'Billing::Subscription' do
    trait :trial do
      plan 'trial'
    end

    factory :trial_subscription, traits: [:trial]
  end
end