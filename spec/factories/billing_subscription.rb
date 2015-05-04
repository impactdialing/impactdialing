FactoryGirl.define do
  factory :bare_subscription, class: 'Billing::Subscription' do

    trait :trial do
      plan 'trial'
    end

    trait :enterprise do
      plan 'enterprise'
    end

    trait :basic do
      plan 'basic'
    end

    trait :pro do
      plan 'pro'
    end

    trait :business do
      plan 'business'
    end

    trait :per_minute do
      plan 'per minute'
    end

    factory :trial_subscription, traits: [:trial]
    factory :enterprise_subscription, traits: [:enterprise]
    factory :basic_subscription, traits: [:basic]
    factory :pro_subscription, traits: [:pro]
    factory :business_subcription, traits: [:business]
    factory :per_minute_subcription, traits: [:per_minute]
  end
end
