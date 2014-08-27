FactoryGirl.define do
  factory :bare_account, class: 'Account' do
    tos_accepted_date Time.now
    record_calls false

    trait :trial do
      # after :create do |account|
      #   association :quota, factory: :trial_quota, {account: account}
      #   association :billing_subscription, factory: :trial_subscription, {account: account}
      # end
    end

    trait :no_funds do
      after :create do |account|
        create(:no_minutes_quota, {account: account})
        create(:trial_subscription, {account: account})
      end
    end

    factory :trial_account, traits: [:trial]
  end
end