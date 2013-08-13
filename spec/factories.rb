FactoryGirl.define do

  sequence :email do |n|
    "user#{n}@example.com"
  end

  sequence :username do |n|
    "user#{n}@example.com"
  end

  sequence :name do |n|
    "user#{n}"
  end

  sequence :phonenumber do |n|
    "#{(10**10)+n}"
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

  factory :admin_user, :parent => :user do
    email 'michael@impactdialing.com'
  end

  factory :billing_account do
  end

  factory :script do
    name 'a script'
    created_at Time.now
    updated_at Time.now
    account
  end

  factory :campaign do
    name 'a campaign'
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
    name 'a campaign'
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
    name 'a campaign'
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
    name 'a campaign'
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
    campaign
    account
    created_at Time.now
    updated_at Time.now
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

  factory :voter do
    first_name { generate(:name) }
    phone { generate(:phonenumber) }
    voter_list
    updated_at Time.now
  end


  factory :caller_session do
    campaign
    caller
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
    created_at Time.now
    updated_at Time.now
  end

  factory :recording do
    name 'name'
    file_file_name 'foo.mp3'
  end

  factory :custom_voter_field do
    name 'name'
  end

  factory :custom_voter_field_value do
  end

  factory :blocked_number do
    account
    number '1234567890'
  end

  factory :script_text do
    content "abc"
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

  end
  factory :transfer_attempt do
  end

  factory :call do
    state 'initial'
  end

  factory :payment do
  end

  factory :caller_group do
    name 'Caller group'
    campaign
    account
  end
end
