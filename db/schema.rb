# encoding: UTF-8
# This file is auto-generated from the current state of the database. Instead
# of editing this file, please use the migrations feature of Active Record to
# incrementally modify your database, and then regenerate this schema definition.
#
# Note that this schema.rb definition is the authoritative source for your
# database schema. If you need to create the application database on another
# system, you should be using db:schema:load, not running all the migrations
# from scratch. The latter is a flawed and unsustainable approach (the more migrations
# you'll amass, the slower it'll run and the greater likelihood for issues).
#
# It's strongly recommended to check this file into your version control system.

ActiveRecord::Schema.define(:version => 20130808073302) do

  create_table "accounts", :force => true do |t|
    t.boolean  "card_verified"
    t.datetime "created_at"
    t.datetime "updated_at"
    t.string   "domain_name"
    t.boolean  "activated",                   :default => false
    t.boolean  "record_calls",                :default => false
    t.string   "recurly_account_code"
    t.string   "subscription_name"
    t.integer  "subscription_count"
    t.boolean  "subscription_active",         :default => false
    t.string   "recurly_subscription_uuid"
    t.boolean  "autorecharge_enabled",        :default => false
    t.float    "autorecharge_trigger"
    t.float    "autorecharge_amount"
    t.integer  "lock_version",                :default => 0
    t.string   "status"
    t.string   "abandonment"
    t.text     "caller_password"
    t.text     "caller_hashed_password_salt"
    t.string   "api_key",                     :default => ""
    t.datetime "tos_accepted_date"
    t.boolean  "credit_card_declined",        :default => false
  end

  create_table "answers", :force => true do |t|
    t.integer  "voter_id",             :null => false
    t.integer  "question_id",          :null => false
    t.integer  "possible_response_id", :null => false
    t.datetime "created_at"
    t.integer  "campaign_id"
    t.integer  "caller_id"
    t.integer  "call_attempt_id"
  end

  add_index "answers", ["campaign_id", "caller_id"], :name => "index_answers_campaign_id_caller_id"
  add_index "answers", ["campaign_id", "created_at", "possible_response_id"], :name => "index_answers_on_campaign_created_at_possible_response"
  add_index "answers", ["possible_response_id", "caller_id", "created_at"], :name => "index_answers_count_possible_response"
  add_index "answers", ["possible_response_id", "campaign_id", "caller_id", "created_at"], :name => "index_answers_count_possible_response_campaign"
  add_index "answers", ["question_id", "campaign_id"], :name => "index_answers_distinct_question"
  add_index "answers", ["question_id", "campaign_id"], :name => "index_distinct_question"
  add_index "answers", ["voter_id", "question_id"], :name => "index_answers_on_voter_id_and_question_id"

  create_table "billing_accounts", :force => true do |t|
    t.integer  "account_id"
    t.string   "cc"
    t.boolean  "active"
    t.datetime "created_at"
    t.datetime "updated_at"
    t.string   "cardtype"
    t.integer  "expires_month"
    t.integer  "expires_year"
    t.string   "last4"
    t.string   "zip"
    t.string   "address1"
    t.string   "city"
    t.string   "state"
    t.string   "country"
    t.string   "name"
    t.string   "checking_account_number"
    t.string   "bank_routing_number"
    t.string   "drivers_license_number"
    t.string   "drivers_license_state"
    t.string   "checking_account_type"
  end

  create_table "blocked_numbers", :force => true do |t|
    t.string   "number"
    t.integer  "account_id"
    t.datetime "created_at",  :null => false
    t.datetime "updated_at",  :null => false
    t.integer  "campaign_id"
  end

  add_index "blocked_numbers", ["account_id", "campaign_id"], :name => "index_blocked_numbers_account_id_campaign_id"

  create_table "call_attempts", :force => true do |t|
    t.integer  "voter_id"
    t.string   "sid"
    t.string   "status"
    t.integer  "campaign_id"
    t.datetime "call_start"
    t.datetime "call_end"
    t.integer  "caller_id"
    t.datetime "connecttime"
    t.integer  "caller_session_id"
    t.datetime "created_at",                                  :null => false
    t.datetime "updated_at",                                  :null => false
    t.string   "result"
    t.string   "result_digit"
    t.string   "tCallSegmentSid"
    t.string   "tAccountSid"
    t.string   "tCalled"
    t.string   "tCaller"
    t.string   "tPhoneNumberSid"
    t.string   "tStatus"
    t.integer  "tDuration"
    t.integer  "tFlags"
    t.datetime "tStartTime"
    t.datetime "tEndTime"
    t.float    "tPrice"
    t.string   "dialer_mode"
    t.datetime "scheduled_date"
    t.string   "recording_url"
    t.integer  "recording_duration"
    t.datetime "wrapup_time"
    t.integer  "payment_id"
    t.integer  "call_id"
    t.boolean  "voter_response_processed", :default => false
    t.boolean  "debited",                  :default => false
  end

  add_index "call_attempts", ["call_end"], :name => "index_call_attempts_on_call_end"
  add_index "call_attempts", ["call_id"], :name => "index_call_attempts_on_call_id"
  add_index "call_attempts", ["caller_id", "wrapup_time"], :name => "index_call_attempts_on_caller_id_and_wrapup_time"
  add_index "call_attempts", ["caller_session_id"], :name => "index_call_attempts_on_caller_session_id"
  add_index "call_attempts", ["campaign_id", "call_end"], :name => "index_call_attempts_on_campaign_id_and_call_end"
  add_index "call_attempts", ["campaign_id", "created_at", "id"], :name => "index_call_attempts_on_campaign_created_id"
  add_index "call_attempts", ["campaign_id", "created_at", "status"], :name => "index_call_attempts_on_campaign_id_created_at_status"
  add_index "call_attempts", ["campaign_id", "wrapup_time"], :name => "index_call_attempts_on_campaign_id_and_wrapup_time"
  add_index "call_attempts", ["campaign_id"], :name => "index_call_attempts_on_campaign_id"
  add_index "call_attempts", ["created_at"], :name => "index_call_attempts_on_created_at"
  add_index "call_attempts", ["debited", "tEndTime"], :name => "index_call_attempts_debit"
  add_index "call_attempts", ["status", "tPrice", "tStatus", "sid"], :name => "index_sync_calls"
  add_index "call_attempts", ["voter_id"], :name => "index_call_attempts_on_voter_id"
  add_index "call_attempts", ["voter_response_processed", "status"], :name => "index_call_attempts_on_voter_response_processed_and_status"

  create_table "caller_groups", :force => true do |t|
    t.string   "name",        :null => false
    t.integer  "campaign_id", :null => false
    t.datetime "created_at",  :null => false
    t.datetime "updated_at",  :null => false
    t.integer  "account_id",  :null => false
  end

  create_table "caller_identities", :force => true do |t|
    t.string   "session_key"
    t.integer  "caller_session_id"
    t.integer  "caller_id"
    t.string   "pin"
    t.datetime "created_at",        :null => false
    t.datetime "updated_at",        :null => false
  end

  add_index "caller_identities", ["pin"], :name => "index_caller_identities_pin"

  create_table "caller_sessions", :force => true do |t|
    t.integer  "caller_id"
    t.integer  "campaign_id"
    t.datetime "endtime"
    t.datetime "starttime"
    t.string   "sid"
    t.boolean  "available_for_call",   :default => false
    t.integer  "voter_in_progress_id"
    t.datetime "created_at",                              :null => false
    t.datetime "updated_at",                              :null => false
    t.boolean  "on_call",              :default => false
    t.string   "caller_number"
    t.string   "tCallSegmentSid"
    t.string   "tAccountSid"
    t.string   "tCalled"
    t.string   "tCaller"
    t.string   "tPhoneNumberSid"
    t.string   "tStatus"
    t.integer  "tDuration"
    t.integer  "tFlags"
    t.datetime "tStartTime"
    t.datetime "tEndTime"
    t.float    "tPrice"
    t.integer  "attempt_in_progress"
    t.string   "session_key"
    t.integer  "payment_id"
    t.string   "state"
    t.string   "type"
    t.string   "digit"
    t.boolean  "debited",              :default => false
    t.integer  "question_id"
    t.string   "caller_type"
    t.integer  "question_number"
    t.integer  "script_id"
    t.string   "reassign_campaign",    :default => "no"
  end

  add_index "caller_sessions", ["caller_id"], :name => "index_caller_sessions_on_caller_id"
  add_index "caller_sessions", ["campaign_id", "on_call"], :name => "index_callers_on_call_group_by_campaign"
  add_index "caller_sessions", ["campaign_id"], :name => "index_caller_sessions_on_campaign_id"
  add_index "caller_sessions", ["sid"], :name => "index_caller_sessions_on_sid"
  add_index "caller_sessions", ["state"], :name => "index_state_caller_sessions"
  add_index "caller_sessions", ["type", "debited", "caller_type", "tEndTime"], :name => "index_caller_session_debit"

  create_table "callers", :force => true do |t|
    t.string   "name"
    t.string   "username"
    t.string   "pin"
    t.integer  "account_id"
    t.boolean  "active",          :default => true
    t.datetime "created_at",                         :null => false
    t.datetime "updated_at",                         :null => false
    t.string   "password"
    t.boolean  "is_phones_only",  :default => false
    t.integer  "campaign_id"
    t.integer  "caller_group_id"
  end

  create_table "calls", :force => true do |t|
    t.integer  "call_attempt_id"
    t.string   "state"
    t.string   "call_sid"
    t.string   "call_status"
    t.string   "answered_by"
    t.integer  "recording_duration"
    t.string   "recording_url"
    t.datetime "created_at",         :null => false
    t.datetime "updated_at",         :null => false
    t.text     "questions"
    t.text     "notes"
    t.text     "all_states"
    t.string   "campaign_type"
  end

  create_table "campaigns", :force => true do |t|
    t.string   "campaign_id"
    t.string   "name"
    t.integer  "account_id"
    t.integer  "script_id"
    t.boolean  "active",                   :default => true
    t.datetime "created_at",                                  :null => false
    t.datetime "updated_at",                                  :null => false
    t.string   "caller_id"
    t.string   "type"
    t.integer  "recording_id"
    t.boolean  "use_recordings",           :default => false
    t.boolean  "calls_in_progress",        :default => false
    t.integer  "recycle_rate",             :default => 1
    t.boolean  "answering_machine_detect"
    t.time     "start_time"
    t.time     "end_time"
    t.string   "time_zone"
    t.float    "acceptable_abandon_rate"
  end

  create_table "custom_voter_field_values", :force => true do |t|
    t.integer "voter_id"
    t.integer "custom_voter_field_id"
    t.string  "value"
  end

  add_index "custom_voter_field_values", ["voter_id"], :name => "index_custom_voter_field_values_on_voter_id"

  create_table "custom_voter_fields", :force => true do |t|
    t.string  "name",       :null => false
    t.integer "account_id"
  end

  create_table "downloaded_reports", :force => true do |t|
    t.integer  "user_id"
    t.string   "link"
    t.datetime "created_at",  :null => false
    t.datetime "updated_at",  :null => false
    t.string   "campaign_id"
  end

  create_table "moderator_campaigns", :force => true do |t|
    t.string "name"
  end

  create_table "moderators", :force => true do |t|
    t.integer  "caller_session_id"
    t.string   "call_sid"
    t.datetime "created_at",        :null => false
    t.datetime "updated_at",        :null => false
    t.string   "session"
    t.string   "active"
    t.integer  "account_id"
  end

  add_index "moderators", ["active", "account_id", "created_at"], :name => "index_moderators_on_active_and_account_id_and_created_at"
  add_index "moderators", ["session", "active", "account_id", "created_at"], :name => "active_moderators"
  add_index "moderators", ["session", "active"], :name => "index_moderators_on_session_and_active"

  create_table "note_responses", :force => true do |t|
    t.integer "voter_id",        :null => false
    t.integer "note_id",         :null => false
    t.string  "response"
    t.integer "call_attempt_id"
    t.integer "campaign_id"
  end

  create_table "notes", :force => true do |t|
    t.text    "note",         :null => false
    t.integer "script_id",    :null => false
    t.integer "script_order"
  end

  create_table "payments", :force => true do |t|
    t.float    "amount_paid"
    t.float    "amount_remaining"
    t.integer  "recurly_transaction_uuid"
    t.integer  "account_id"
    t.string   "notes"
    t.datetime "created_at",               :null => false
    t.datetime "updated_at",               :null => false
  end

  create_table "possible_responses", :force => true do |t|
    t.integer "question_id"
    t.integer "keypad"
    t.string  "value"
    t.boolean "retry",                   :default => false
    t.integer "possible_response_order"
    t.string  "external_id_field"
  end

  add_index "possible_responses", ["question_id", "keypad", "possible_response_order"], :name => "index_possible_responses_question_keypad_possible_response_order"

  create_table "questions", :force => true do |t|
    t.integer "script_id",         :null => false
    t.text    "text",              :null => false
    t.integer "script_order"
    t.string  "external_id_field"
  end

  create_table "recordings", :force => true do |t|
    t.integer  "account_id"
    t.integer  "active",            :default => 1
    t.string   "name"
    t.datetime "created_at",                       :null => false
    t.datetime "updated_at",                       :null => false
    t.string   "file_file_name"
    t.string   "file_content_type"
    t.string   "file_file_size"
    t.datetime "file_updated_at"
  end

  create_table "script_texts", :force => true do |t|
    t.integer "script_id"
    t.text    "content"
    t.integer "script_order"
  end

  create_table "scripts", :force => true do |t|
    t.string   "name"
    t.boolean  "active",                             :default => true
    t.integer  "account_id"
    t.datetime "created_at",                                           :null => false
    t.datetime "updated_at",                                           :null => false
    t.text     "voter_fields", :limit => 2147483647
  end

  create_table "simulated_values", :force => true do |t|
    t.integer  "campaign_id"
    t.datetime "created_at",           :null => false
    t.datetime "updated_at",           :null => false
    t.float    "best_dials"
    t.float    "best_conversation"
    t.float    "longest_conversation"
    t.float    "best_wrapup_time"
  end

  create_table "subscriptions", :force => true do |t|
    t.string   "type",                    :default => "Trial", :null => false
    t.integer  "number_of_callers",       :default => 0
    t.integer  "minutes_utlized",         :default => 0
    t.integer  "total_allowed_minutes",   :default => 0
    t.integer  "account_id"
    t.datetime "subscription_start_date"
    t.datetime "created_at",                                   :null => false
    t.datetime "updated_at",                                   :null => false
    t.string   "stripe_customer_id"
    t.string   "cc_last4"
    t.string   "exp_month"
    t.string   "exp_year"
  end

  create_table "temp_voter_lists", :force => true do |t|
    t.string   "name"
    t.datetime "created_at", :null => false
    t.datetime "updated_at", :null => false
  end

  create_table "transfer_attempts", :force => true do |t|
    t.integer  "transfer_id"
    t.integer  "caller_session_id"
    t.integer  "call_attempt_id"
    t.integer  "script_id"
    t.integer  "campaign_id"
    t.datetime "call_start"
    t.datetime "call_end"
    t.string   "status"
    t.datetime "connecttime"
    t.string   "sid"
    t.string   "session_key"
    t.datetime "created_at",        :null => false
    t.datetime "updated_at",        :null => false
    t.string   "transfer_type"
    t.float    "tPrice"
    t.string   "tStatus"
    t.string   "tCallSegmentSid"
    t.string   "tAccountSid"
    t.string   "tCalled"
    t.string   "tCaller"
    t.string   "tPhoneNumberSid"
    t.datetime "tStartTime"
    t.datetime "tEndTime"
    t.integer  "tDuration"
    t.integer  "tFlags"
  end

  create_table "transfers", :force => true do |t|
    t.string   "label"
    t.string   "phone_number"
    t.string   "transfer_type"
    t.integer  "script_id"
    t.datetime "created_at",    :null => false
    t.datetime "updated_at",    :null => false
  end

  create_table "users", :force => true do |t|
    t.string   "fname"
    t.string   "lname"
    t.string   "orgname"
    t.string   "email"
    t.boolean  "active",              :default => true
    t.datetime "created_at",                            :null => false
    t.datetime "updated_at",                            :null => false
    t.string   "hashed_password"
    t.string   "salt"
    t.string   "password_reset_code"
    t.string   "phone"
    t.integer  "account_id"
    t.string   "role"
  end

  create_table "voter_lists", :force => true do |t|
    t.string   "name"
    t.string   "account_id"
    t.boolean  "active",             :default => true
    t.datetime "created_at",                           :null => false
    t.datetime "updated_at",                           :null => false
    t.integer  "campaign_id"
    t.boolean  "enabled",            :default => true
    t.string   "separator"
    t.text     "headers"
    t.text     "csv_to_system_map"
    t.text     "s3path"
    t.string   "uploaded_file_name"
  end

  add_index "voter_lists", ["account_id", "name"], :name => "index_voter_lists_on_user_id_and_name", :unique => true

  create_table "voters", :force => true do |t|
    t.string   "Phone"
    t.string   "CustomID"
    t.string   "LastName"
    t.string   "FirstName"
    t.string   "MiddleName"
    t.string   "Suffix"
    t.string   "Email"
    t.string   "result"
    t.integer  "caller_session_id"
    t.integer  "campaign_id"
    t.integer  "account_id"
    t.boolean  "active",                 :default => true
    t.datetime "created_at",                                       :null => false
    t.datetime "updated_at",                                       :null => false
    t.string   "status",                 :default => "not called"
    t.integer  "voter_list_id"
    t.boolean  "call_back",              :default => false
    t.integer  "caller_id"
    t.string   "result_digit"
    t.integer  "attempt_id"
    t.datetime "result_date"
    t.integer  "last_call_attempt_id"
    t.datetime "last_call_attempt_time"
    t.integer  "num_family",             :default => 1
    t.integer  "family_id_answered"
    t.text     "result_json"
    t.datetime "scheduled_date"
    t.string   "address"
    t.string   "city"
    t.string   "state"
    t.string   "zip_code"
    t.string   "country"
    t.datetime "skipped_time"
    t.string   "priority"
    t.integer  "lock_version",           :default => 0
    t.boolean  "enabled",                :default => true
  end

  add_index "voters", ["Phone", "voter_list_id"], :name => "index_voters_on_Phone_and_voter_list_id"
  add_index "voters", ["attempt_id"], :name => "index_voters_on_attempt_id"
  add_index "voters", ["caller_session_id"], :name => "index_voters_on_caller_session_id"
  add_index "voters", ["campaign_id", "active", "status", "call_back"], :name => "index_voters_on_campaign_id_and_active_and_status_and_call_back"
  add_index "voters", ["campaign_id", "enabled", "priority", "status"], :name => "index_priority_voters"
  add_index "voters", ["campaign_id", "status", "id"], :name => "index_voters_on_campaign_id_and_status_and_id"
  add_index "voters", ["campaign_id", "status", "last_call_attempt_time"], :name => "voters_campaign_status_time"
  add_index "voters", ["status"], :name => "index_voters_on_status"
  add_index "voters", ["voter_list_id"], :name => "index_voters_on_voter_list_id"

end
