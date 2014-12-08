FactoryGirl.define do
  factory :household, class: 'Household' do
    account
    campaign
    voter_list
    phone { Forgery(:address).phone }
    enabled [:list]

    trait :blocked do
      enabled [:list, :blocked]
    end

    trait :disabled do
      enabled []
    end
  end
end