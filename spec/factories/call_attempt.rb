FactoryGirl.define do
  factory :bare_call_attempt, class: 'CallAttempt' do
    # all associations, sans (created|updated)_at fields

    trait :failed do
      status 'Call failed'
      tDuration nil
      tStatus 'failed'
      call_end { Time.now }
    end

    trait :ready do
      status CallAttempt::Status::READY
    end

    trait :in_progress do
      status CallAttempt::Status::INPROGRESS
    end

    trait :busy do
      status 'No answer busy signal'
      tStatus 'busy'
      call_end { Time.now }
    end

    trait :abandoned do
      status CallAttempt::Status::ABANDONED
      tStatus 'completed'
      call_end { Time.now }
    end

    trait :completed do
      status 'Call completed with success.'
      tStatus 'completed'
      tDuration { Forgery(:basic).number(at_least: 30, at_most: 180) }
      call_end { Time.now }
    end

    trait :voicemail_delivered do
      recording_id { Forgery(:basic).number }
      status CallAttempt::Status::VOICEMAIL
      call_end { Time.now }
    end

    trait :machine_hangup do
      status CallAttempt::Status::HANGUP
      call_end { Time.now }
    end

    trait :machine_answered do
      status CallAttempt::Status::VOICEMAIL
      tStatus 'completed'
      tDuration { Forgery(:basic).number(at_least: 30, at_most: 180) }
      call_end { Time.now }
    end

    trait :past_recycle_time do
      created_at 25.hours.ago
      call_end 25.hours.ago
    end

    factory :busy_call_attempt, traits: [:busy]
    factory :failed_call_attempt, traits: [:failed]
    factory :completed_call_attempt, traits: [:completed]
    factory :machine_answered_call_attempt, traits: [:machine_answered]
    factory :past_recycle_time_failed_call_attempt, traits: [:failed, :past_recycle_time]
    factory :past_recycle_time_busy_call_attempt, traits: [:busy, :past_recycle_time]
    factory :past_recycle_time_completed_call_attempt, traits: [:completed, :past_recycle_time]
    factory :past_recycle_time_machine_answered_call_attempt, traits: [:machine_answered, :past_recycle_time]
  end
end