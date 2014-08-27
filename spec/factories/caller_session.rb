FactoryGirl.define do
  factory :bare_caller_session, class: 'CallerSession' do
    trait :webui do
      type 'WebuiCallerSession'
    end
    trait :phones_only do
      type 'PhonesOnlyCallerSession'
    end

    trait :available do
      available_for_call true
      on_call true
    end
    trait :not_available do
      available_for_call false
      on_call true
    end
  end
end