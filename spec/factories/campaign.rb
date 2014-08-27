FactoryGirl.define do
  factory :bare_campaign, class: 'Campaign' do
    name         { Forgery(:name).company_name }
    caller_id    '1234567890'
    recycle_rate 1
    start_time   (6.hours.ago)
    end_time     (6.hours.ago)
    time_zone    "Pacific Time (US & Canada)"

    trait :preview do
      type 'Preview'
    end

    trait :power do
      type 'Power'
    end

    trait :predictive do
      type 'Predictive'
      acceptable_abandon_rate 0.03
    end

    trait :with_recording do
      recording
    end

    factory :bare_preview, traits: [:preview], class: 'Preview'
    factory :bare_power, traits: [:power], class: 'Power'
    factory :bare_predictive, traits: [:predictive], class: 'Predictive'
    factory :predictive_with_recording, traits: [:predictive, :with_recording], class: 'Predictive'
    factory :power_with_recording, traits: [:power, :with_recording], class: 'Power'
    factory :preview_with_recording, traits: [:preview, :with_recording], class: 'Preview'
  end
end
