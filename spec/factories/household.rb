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

    trait :success do
      status CallAttempt::Status::SUCCESS
    end

    trait :failed do
      status CallAttempt::Status::FAILED
    end

    trait :busy do
      status CallAttempt::Status::BUSY
    end

    trait :abandoned do
      status CallAttempt::Status::ABANDONED
    end

    trait :no_answer do
      status CallAttempt::Status::NOANSWER
    end

    trait :voicemail do
      status CallAttempt::Status::VOICEMAIL
    end

    trait :hangup do
      status CallAttempt::Status::HANGUP
    end
  end
end