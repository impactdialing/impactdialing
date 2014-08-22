FactoryGirl.define do
  factory :bare_voter, class: 'Voter' do
    first_name { Forgery(:name).first_name }
    phone { Forgery(:address).phone }
    updated_at Time.now

    factory :realistic_voter do
      last_name { Forgery(:name).last_name }
      email { Forgery(:email).address }
      address { Forgery(:address).street_address }
      city { Forgery(:address).city }
      state { Forgery(:address).state }
      zip_code { Forgery(:address).zip }
      country { Forgery(:address).country }


      trait :ringing do
        status CallAttempt::Status::RINGING
        last_call_attempt_time { 30.seconds.ago }
      end

      trait :queued do
        status CallAttempt::Status::READY
        last_call_attempt_time { Time.now }
      end

      trait :in_progress do
        status CallAttempt::Status::INPROGRESS
        last_call_attempt_time { 45.seconds.ago }
      end

      trait :failed do
        status CallAttempt::Status::FAILED
      end

      trait :disabled do
        enabled false
      end

      trait :deleted do
        active false
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

      trait :hangup do
        status CallAttempt::Status::HANGUP
      end

      trait :voicemail do
        status CallAttempt::Status::VOICEMAIL
      end

      trait :success do
        status CallAttempt::Status::SUCCESS
      end

      trait :skipped do
        status Voter::Status::SKIPPED
        skipped_time 5.minutes.ago
      end

      trait :scheduled do
        status CallAttempt::Status::SCHEDULED
      end

      trait :scheduled_soon do
        :scheduled
        scheduled_date 1.minute.from_now
      end

      trait :scheduled_later do
        :scheduled
        scheduled_date 30.minutes.from_now
      end

      trait :high_priority do
        priority "1"
      end

      trait :recently_dialed do
        last_call_attempt_time { 5.minutes.ago }
      end

      trait :not_recently_dialed do
        last_call_attempt_time { 25.hours.ago }
      end

      trait :call_back do
        call_back true
      end

      factory :ringing_voter, traits: [:ringing]
      factory :queued_voter, traits: [:queued]
      factory :failed_voter, traits: [:failed]
      factory :in_progress_voter, traits: [:in_progress]
      factory :disabled_voter, traits: [:disabled]
      factory :deleted_voter, traits: [:deleted]
    end
  end
end
