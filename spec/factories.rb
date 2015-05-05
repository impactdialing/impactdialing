FactoryGirl.define do

  sequence :email do |n|
    "user#{n}@example.com"
  end

  sequence :username do |n|
    "user#{n}@example.com"
  end

  sequence :name do |n|
    "ObjectName#{n}"
  end

  sequence :phonenumber do |n|
    "#{(10**10)+n}"
  end

  sequence :campaign_name do |n|
    "campaign #{n}"
  end

  sequence :sid do |n|
    "sid#{n}"
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
    caller_id '1234567890'
    account
    recycle_rate 1
    start_time (Time.now - 6.hours)
    end_time (Time.now - 7.hours)
    time_zone "Pacific Time (US & Canada)"
    script
    type 'Preview'
    created_at Time.now
    updated_at Time.now
  end

  factory :predictive do
    name { "predictive #{generate(:campaign_name)}" }
    caller_id '1234567890'
    account
    recycle_rate 1
    start_time (Time.now - 6.hours)
    end_time (Time.now - 7.hours)
    time_zone "Pacific Time (US & Canada)"
    script
    created_at Time.now
    updated_at Time.now
  end

  factory :preview do
    name { "preview #{generate(:campaign_name)}" }
    caller_id '1234567890'
    account
    recycle_rate 1
    start_time (Time.now - 6.hours)
    end_time (Time.now - 7.hours)
    time_zone "Pacific Time (US & Canada)"
    script
    created_at Time.now
    updated_at Time.now
  end

  factory :power do
    name { "power #{generate(:campaign_name)}" }
    caller_id '1234567890'
    account
    recycle_rate 1
    start_time (Time.now - 6.hours)
    end_time (Time.now - 7.hours)
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
    csv_to_system_map Hash["Phone" => "Phone"]
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
      state 'initial'
      created_at Time.now
      updated_at Time.now
  end

  factory :phones_only_caller_session do
    state 'initial'
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
  end
  factory :transfer_attempt do
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
