distributed_n = -> (n){
  if ENV['TEST_ENV_NUMBER']
    "#{n}#{ENV['TEST_ENV_NUMBER']}".to_i + rand(10_000)
  else
    n + rand(10_000)
  end
}
FactoryGirl.define do

  sequence :email do |n|
    n = distributed_n.call(n)
    "#{n}#{Forgery(:internet).email_address}"
  end

  sequence :username do |n|
    n = distributed_n.call(n)
    "#{n}#{Forgery(:internet).email_address}"
  end

  sequence :name do |n|
    "ObjectName#{n}"
  end

  sequence :phonenumber do |n|
    "#{(10**10)+n}"
  end

  sequence :campaign_name do |n|
    n = distributed_n.call(n)
    "#{n}#{Forgery(:name).company_name}"
  end

  sequence :sid do |n|
    n = distributed_n.call(n)
    "sid#{UUID.new.generate.gsub('-','')}"
  end

  sequence :random_string do |n|
    chars = ('a'..'z').to_a
    chars.sample(n + 7).join
  end

  factory :account do
    tos_accepted_date Time.now
    record_calls false
  end

  factory :user do
    account
    email { generate(:email) }
    new_password 'password'
    role "admin"
  end

  factory :script do
    name 'a script'
    created_at Time.now
    updated_at Time.now
    account
  end

  factory :question do
    text "question text"
    script_order '1'
    script
  end

  factory :possible_response do
    value "no_response"
    possible_response_order '1'
    question
    keypad ""
  end

  factory :answer do
    caller
    possible_response
    question
  end

  factory :campaign do
    name { "a #{generate(:campaign_name)}" }
    caller_id '2234567890'
    account
    recycle_rate 1
    start_time (Time.now)
    end_time (Time.now)
    time_zone "Pacific Time (US & Canada)"
    script
    type 'Preview'
    created_at Time.now
    updated_at Time.now
  end

  factory :predictive do
    name { "predictive #{generate(:campaign_name)}" }
    caller_id '2234567890'
    account
    recycle_rate 1
    start_time (Time.now)
    end_time (Time.now)
    time_zone "Pacific Time (US & Canada)"
    script
    created_at Time.now
    updated_at Time.now
  end

  factory :preview do
    name { "preview #{generate(:campaign_name)}" }
    caller_id '2234567890'
    account
    recycle_rate 1
    start_time (Time.now)
    end_time (Time.now)
    time_zone "Pacific Time (US & Canada)"
    script
    created_at Time.now
    updated_at Time.now
  end

  factory :power do
    name { "power #{generate(:campaign_name)}" }
    caller_id '2234567890'
    account
    recycle_rate 1
    start_time (Time.now)
    end_time (Time.now)
    time_zone "Pacific Time (US & Canada)"
    script
    created_at Time.now
    updated_at Time.now
  end

  factory :caller do
    username { generate(:username) }
    name 'a caller'
    password 'secret'
    created_at Time.now
    updated_at Time.now

    after(:build) do |caller|
      caller.account ||= create(:account)
      caller.campaign ||= create([:preview, :power, :predictive].sample, account: caller.account)
      caller.account = caller.campaign.account
    end
  end

  factory :voter_list do
    enabled { true }
    campaign
    name { generate(:name) }
    account
    headers "Phone,Name,Email,Address,City,ZipCode,State,Country"
    separator ","
    s3path "abc"
    uploaded_file_name "abc.csv"
    csv_to_system_map Hash["Phone" => "phone", "ID" => "custom_id"]
    created_at Time.now
    updated_at Time.now
  end

  factory :caller_session do
    campaign
    caller
    sid { generate(:sid) }
    state 'initial'
    created_at Time.now
  end

  factory :webui_caller_session do
    caller
    sid { generate(:sid) }
    state 'initial'
    created_at Time.now
    updated_at Time.now
  end

  factory :phones_only_caller_session do
    state 'initial'
    sid { generate(:sid) }
    created_at Time.now
    updated_at Time.now
  end

  factory :caller_identity do |s|
    caller
    created_at Time.now
    updated_at Time.now
  end

  factory :call_attempt do
    campaign
    caller
    caller_session
    created_at Time.now
    updated_at Time.now
    factory :answered_call_attempt do
      tDuration 55
    end
  end

  factory :recording do
    name 'name'
    file_file_name 'foo.mp3'
  end

  factory :custom_voter_field do
    name { generate(:name) }
  end

  factory :custom_voter_field_value do
    custom_voter_field
    value { generate(:name) }
  end

  factory :blocked_number do
    account
    number { Forgery(:address).phone }
  end

  factory :script_text do
    content "abc"
  end

  factory :caller_campaign do
  end

  factory :note do
    note 'here is a note'
    script
    script_order '1'
  end

  factory :note_response do
  end


  factory :moderator do
  end

  factory :simulated_values do
  end

  factory :transfer do
    phone_number { Forgery(:address).phone }
    label { Forgery(:name).first_name }
  end
  factory :transfer_attempt do
    transfer

    trait :with_session_key do
      session_key { Forgery(:name).first_name }
    end
  end

  factory :call do
    call_attempt
    state 'initial'
  end

  factory :caller_group do
    name 'Caller group'
    campaign
    account
  end
end
