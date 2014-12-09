FactoryGirl.define do
  factory :household, class: 'Household' do
    account
    campaign
    phone { Forgery(:address).phone }

    trait :cell do
      blocked [:cell]
    end

    trait :dnc do
      blocked [:dnc]
    end

    trait :dnc_and_cell_blocked do
      blocked [:dnc, :cell]
    end
  end
end