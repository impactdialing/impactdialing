FactoryGirl.define do
  factory :bare_quota, class: 'Quota' do
    trait :trial do
      minutes_allowed 50
    end

    trait :no_minutes do
      minutes_allowed 0
    end

    factory :no_minute_quota, traits: [:no_minutes]
    factory :trial_quota, traits: [:trial]
  end
end