# This file is auto-generated from the current state of the database. Instead of editing this file, 
# please use the migrations feature of Active Record to incrementally modify your database, and
# then regenerate this schema definition.
#
# Note that this schema.rb definition is the authoritative source for your database schema. If you need
# to create the application database on another system, you should be using db:schema:load, not running
# all the migrations from scratch. The latter is a flawed and unsustainable approach (the more migrations
# you'll amass, the slower it'll run and the greater likelihood for issues).
#
# It's strongly recommended to check this file into your version control system.

ActiveRecord::Schema.define(:version => 20110704134148) do

  create_table "accounts", :force => true do |t|
    t.integer  "user_id"
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
  end

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
    t.integer  "caller_hold_time"
    t.datetime "created_at"
    t.datetime "updated_at"
    t.string   "result"
    t.string   "result_digit"
    t.string   "tCallSegmentSid"
    t.string   "tAccountSid"
    t.string   "tCalled"
    t.string   "tCaller"
    t.string   "tPhoneNumberSid"
    t.integer  "tStatus"
    t.integer  "tDuration"
    t.integer  "tFlags"
    t.datetime "tStartTime"
    t.datetime "tEndTime"
    t.float    "tPrice"
    t.datetime "answertime"
    t.string   "dialer_mode"
    t.text     "result_json"
  end

  add_index "call_attempts", ["call_end"], :name => "index_call_attempts_on_call_end"
  add_index "call_attempts", ["caller_session_id"], :name => "index_call_attempts_on_caller_session_id"
  add_index "call_attempts", ["campaign_id"], :name => "index_call_attempts_on_campaign_id"
  add_index "call_attempts", ["voter_id"], :name => "index_call_attempts_on_voter_id"

  create_table "call_responses", :force => true do |t|
    t.integer  "call_attempt_id"
    t.string   "response"
    t.integer  "recording_response_id"
    t.datetime "created_at"
    t.datetime "updated_at"
  end

  create_table "caller_sessions", :force => true do |t|
    t.integer  "caller_id"
    t.integer  "campaign_id"
    t.datetime "endtime"
    t.datetime "starttime"
    t.integer  "num_calls"
    t.integer  "avg_wait"
    t.string   "sid"
    t.boolean  "available_for_call",  :default => false
    t.integer  "voter_in_progress"
    t.datetime "hold_time_start"
    t.datetime "created_at"
    t.datetime "updated_at"
    t.boolean  "on_call",             :default => false
    t.string   "caller_number"
    t.string   "tCallSegmentSid"
    t.string   "tAccountSid"
    t.string   "tCalled"
    t.string   "tCaller"
    t.string   "tPhoneNumberSid"
    t.integer  "tStatus"
    t.integer  "tDuration"
    t.integer  "tFlags"
    t.datetime "tStartTime"
    t.datetime "tEndTime"
    t.float    "tPrice"
    t.integer  "attempt_in_progress"
    t.string   "session_key"
  end

  add_index "caller_sessions", ["caller_id"], :name => "index_caller_sessions_on_caller_id"
  add_index "caller_sessions", ["campaign_id"], :name => "index_caller_sessions_on_campaign_id"

  create_table "callers", :force => true do |t|
    t.string   "name"
    t.string   "email"
    t.string   "pin"
    t.integer  "user_id"
    t.boolean  "multi_user", :default => true
    t.boolean  "active",     :default => true
    t.datetime "created_at"
    t.datetime "updated_at"
    t.string   "password"
  end

  create_table "callers_campaigns", :id => false, :force => true do |t|
    t.integer "caller_id"
    t.integer "campaign_id"
  end

  create_table "campaigns", :force => true do |t|
    t.string   "campaign_id"
    t.string   "group_id"
    t.string   "name"
    t.string   "keypad_0"
    t.integer  "user_id"
    t.integer  "script_id"
    t.boolean  "active",                   :default => true
    t.datetime "created_at"
    t.datetime "updated_at"
    t.float    "ratio_2",                  :default => 33.0
    t.float    "ratio_3",                  :default => 20.0
    t.float    "ratio_4",                  :default => 12.0
    t.float    "ratio_override",           :default => 0.0
    t.string   "ending_window_method",     :default => "Not used"
    t.string   "caller_id"
    t.boolean  "caller_id_verified",       :default => false
    t.boolean  "use_answering",            :default => true
    t.string   "predective_type",          :default => "preview"
    t.integer  "recording_id"
    t.boolean  "use_recordings",           :default => false
    t.integer  "max_calls_per_caller",     :default => 20
    t.string   "callin_number",            :default => "4157020991"
    t.boolean  "use_web_ui",               :default => true
    t.integer  "answer_detection_timeout", :default => 20
    t.boolean  "calls_in_progress",        :default => false
    t.boolean  "robo",                     :default => false
  end

  create_table "campaigns_voter_lists", :id => false, :force => true do |t|
    t.integer "campaign_id"
    t.integer "voter_list_id"
  end

  create_table "dumps", :force => true do |t|
    t.integer  "request_id"
    t.integer  "first_line"
    t.integer  "last_line"
    t.integer  "completed_id"
    t.integer  "completed_lineno"
    t.float    "duration"
    t.integer  "status"
    t.string   "url"
    t.integer  "params_id"
    t.integer  "params_line"
    t.string   "params"
    t.string   "guid"
    t.datetime "created_at"
    t.datetime "updated_at"
  end

  add_index "dumps", ["guid"], :name => "index_dumps_on_guid"

  create_table "families", :force => true do |t|
    t.integer  "voter_id"
    t.string   "Phone"
    t.string   "CustomID"
    t.string   "LastName"
    t.string   "FirstName"
    t.string   "MiddleName"
    t.string   "Suffix"
    t.string   "Email"
    t.string   "result"
    t.integer  "campaign_id"
    t.integer  "user_id"
    t.boolean  "active",                 :default => true
    t.datetime "created_at"
    t.datetime "updated_at"
    t.string   "status",                 :default => "not called"
    t.integer  "voter_list_id"
    t.integer  "caller_session_id"
    t.boolean  "call_back",              :default => false
    t.integer  "caller_id"
    t.string   "result_digit"
    t.string   "Age"
    t.string   "Gender"
    t.integer  "attempt_id"
    t.datetime "result_date"
    t.integer  "last_call_attempt_id"
    t.datetime "last_call_attempt_time"
  end

  create_table "lists", :force => true do |t|
    t.string   "name"
    t.integer  "group_id"
    t.integer  "user_id"
    t.datetime "created_at"
    t.datetime "updated_at"
  end

  create_table "recording_responses", :force => true do |t|
    t.integer "robo_recording_id"
    t.string  "response"
    t.integer "keypad"
  end

  create_table "recordings", :force => true do |t|
    t.integer  "user_id"
    t.string   "recording_url"
    t.integer  "active",        :default => 1
    t.string   "name"
    t.datetime "created_at"
    t.datetime "updated_at"
  end

  create_table "robo_recordings", :force => true do |t|
    t.integer  "script_id"
    t.string   "name"
    t.string   "file_file_name"
    t.string   "file_content_type"
    t.integer  "file_file_size"
    t.datetime "file_updated_at"
  end

  create_table "scripts", :force => true do |t|
    t.string   "name"
    t.text     "script"
    t.boolean  "active",        :default => true
    t.integer  "user_id"
    t.datetime "created_at"
    t.datetime "updated_at"
    t.text     "keypad_1"
    t.text     "keypad_2"
    t.text     "keypad_3"
    t.text     "keypad_4"
    t.text     "keypad_5"
    t.text     "keypad_6"
    t.text     "keypad_7"
    t.text     "keypad_8"
    t.text     "keypad_9"
    t.text     "keypad_10"
    t.text     "keypad_11"
    t.text     "keypad_12"
    t.text     "keypad_13"
    t.text     "keypad_14"
    t.text     "keypad_15"
    t.text     "keypad_16"
    t.text     "keypad_17"
    t.text     "keypad_18"
    t.text     "keypad_19"
    t.text     "keypad_20"
    t.text     "keypad_21"
    t.text     "keypad_22"
    t.text     "keypad_23"
    t.text     "keypad_24"
    t.text     "keypad_25"
    t.text     "keypad_26"
    t.text     "keypad_27"
    t.text     "keypad_28"
    t.text     "keypad_29"
    t.text     "keypad_30"
    t.text     "keypad_31"
    t.text     "keypad_32"
    t.text     "keypad_33"
    t.text     "keypad_34"
    t.text     "keypad_35"
    t.text     "keypad_36"
    t.text     "keypad_37"
    t.text     "keypad_38"
    t.text     "keypad_39"
    t.text     "keypad_40"
    t.text     "keypad_41"
    t.text     "keypad_42"
    t.text     "keypad_43"
    t.text     "keypad_44"
    t.text     "keypad_45"
    t.text     "keypad_46"
    t.text     "keypad_47"
    t.text     "keypad_48"
    t.text     "keypad_49"
    t.text     "keypad_50"
    t.text     "keypad_51"
    t.text     "keypad_52"
    t.text     "keypad_53"
    t.text     "keypad_54"
    t.text     "keypad_55"
    t.text     "keypad_56"
    t.text     "keypad_57"
    t.text     "keypad_58"
    t.text     "keypad_59"
    t.text     "keypad_60"
    t.text     "keypad_61"
    t.text     "keypad_62"
    t.text     "keypad_63"
    t.text     "keypad_64"
    t.text     "keypad_65"
    t.text     "keypad_66"
    t.text     "keypad_67"
    t.text     "keypad_68"
    t.text     "keypad_69"
    t.text     "keypad_70"
    t.text     "keypad_71"
    t.text     "keypad_72"
    t.text     "keypad_73"
    t.text     "keypad_74"
    t.text     "keypad_75"
    t.text     "keypad_76"
    t.text     "keypad_77"
    t.text     "keypad_78"
    t.text     "keypad_79"
    t.text     "keypad_80"
    t.text     "keypad_81"
    t.text     "keypad_82"
    t.text     "keypad_83"
    t.text     "keypad_84"
    t.text     "keypad_85"
    t.text     "keypad_86"
    t.text     "keypad_87"
    t.text     "keypad_88"
    t.text     "keypad_89"
    t.text     "keypad_90"
    t.text     "keypad_91"
    t.text     "keypad_92"
    t.text     "keypad_93"
    t.text     "keypad_94"
    t.text     "keypad_95"
    t.text     "keypad_96"
    t.text     "keypad_97"
    t.text     "keypad_98"
    t.text     "keypad_99"
    t.string   "incompletes"
    t.string   "voter_fields"
    t.text     "result_set_1"
    t.text     "result_set_2"
    t.text     "result_set_3"
    t.text     "result_set_4"
    t.text     "result_set_5"
    t.text     "result_set_6"
    t.text     "result_set_7"
    t.text     "result_set_8"
    t.text     "result_set_9"
    t.text     "result_set_10"
    t.string   "note_1"
    t.string   "note_2"
    t.string   "note_3"
    t.string   "note_4"
    t.string   "note_5"
    t.string   "note_6"
    t.string   "note_7"
    t.string   "note_8"
    t.string   "note_9"
    t.string   "note_10"
    t.boolean  "robo",          :default => false
  end

  create_table "seos", :force => true do |t|
    t.string   "action"
    t.string   "controller"
    t.string   "crmkey"
    t.string   "title"
    t.string   "keywords"
    t.string   "description"
    t.text     "content",     :limit => 2147483647
    t.boolean  "active"
    t.datetime "created_at"
    t.datetime "updated_at"
    t.string   "version"
  end

  create_table "users", :force => true do |t|
    t.string   "fname"
    t.string   "lname"
    t.string   "orgname"
    t.string   "email"
    t.boolean  "active",              :default => true
    t.datetime "created_at"
    t.datetime "updated_at"
    t.boolean  "paid",                :default => false
    t.string   "hashed_password"
    t.string   "salt"
    t.string   "password_reset_code"
  end

  create_table "voter_lists", :force => true do |t|
    t.string   "name"
    t.string   "user_id"
    t.boolean  "active",      :default => true
    t.datetime "created_at"
    t.datetime "updated_at"
    t.integer  "campaign_id"
    t.boolean  "enabled",     :default => true
  end

  add_index "voter_lists", ["user_id", "name"], :name => "index_voter_lists_on_user_id_and_name", :unique => true

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
    t.integer  "user_id"
    t.boolean  "active",                 :default => true
    t.datetime "created_at"
    t.datetime "updated_at"
    t.string   "status",                 :default => "not called"
    t.integer  "voter_list_id"
    t.boolean  "call_back",              :default => false
    t.integer  "caller_id"
    t.string   "result_digit"
    t.integer  "attempt_id"
    t.datetime "result_date"
    t.integer  "last_call_attempt_id"
    t.datetime "last_call_attempt_time"
    t.string   "Age"
    t.string   "Gender"
    t.integer  "num_family",             :default => 1
    t.integer  "family_id_answered"
    t.text     "result_json"
  end

  add_index "voters", ["Phone", "voter_list_id"], :name => "index_voters_on_Phone_and_voter_list_id", :unique => true
  add_index "voters", ["Phone"], :name => "index_voters_on_Phone"
  add_index "voters", ["attempt_id"], :name => "index_voters_on_attempt_id"
  add_index "voters", ["campaign_id"], :name => "index_voters_on_campaign_id"
  add_index "voters", ["status"], :name => "index_voters_on_status"
  add_index "voters", ["voter_list_id"], :name => "index_voters_on_voter_list_id"

end
