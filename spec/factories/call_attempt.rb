FactoryGirl.define do
  factory :bare_call_attempt, class: 'CallAttempt' do
    # all associations, sans (created|updated)_at fields

    trait :failed do
      status 'Call failed'
      tDuration nil
      tStatus 'failed'
    end

    trait :ready do
      status CallAttempt::Status::READY
    end

    trait :busy do
      status 'No answer busy signal'
      tStatus 'busy'
    end

    trait :abandoned do
      status CallAttempt::Status::ABANDONED
      tStatus 'completed'
    end

    trait :completed do
      status 'Call completed with success.'
      tStatus 'completed'
      tDuration { Forgery(:basic).number(at_least: 30, at_most: 180) }
    end

    trait :machine_answered do
      status 'Message delivered'
      tStatus 'completed'
      tDuration { Forgery(:basic).number(at_least: 30, at_most: 180) }
    end

    trait :past_recycle_time do
      created_at 25.hours.ago
    end

    factory :past_recycle_time_failed_call_attempt, traits: [:failed, :past_recycle_time]
    factory :past_recycle_time_busy_call_attempt, traits: [:busy, :past_recycle_time]
    factory :past_recycle_time_completed_call_attempt, traits: [:completed, :past_recycle_time]
    factory :past_recycle_time_machine_answered_call_attempt, traits: [:machine_answered, :past_recycle_time]
  end
end