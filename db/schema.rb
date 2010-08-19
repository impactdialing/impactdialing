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

ActiveRecord::Schema.define(:version => 20100817115742) do

  create_table "call_attempts", :force => true do |t|
    t.integer  "voter_id"
    t.string   "sid"
    t.string   "status"
    t.integer  "campaign_id"
    t.datetime "created_at"
    t.datetime "updated_at"
  end

  create_table "caller_sessions", :force => true do |t|
    t.integer  "caller_id"
    t.integer  "campaign_id"
    t.datetime "endtime"
    t.integer  "num_calls"
    t.integer  "avg_wait"
    t.string   "guid"
    t.datetime "created_at"
    t.datetime "updated_at"
    t.integer  "available_for_call", :limit => 1, :default => 1
    t.datetime "starttime"
    t.integer  "voter_in_progress"
  end

  create_table "callers", :force => true do |t|
    t.string   "name"
    t.string   "email"
    t.string   "pin"
    t.datetime "created_at"
    t.datetime "updated_at"
    t.integer  "user_id"
    t.integer  "active",     :limit => 1, :default => 1
    t.integer  "multi_user", :limit => 1, :default => 1
  end

  create_table "callers_campaigns", :id => false, :force => true do |t|
    t.integer "caller_id"
    t.integer "campaign_id"
  end

  create_table "campaigns", :force => true do |t|
    t.string   "campaign_id"
    t.string   "group_id"
    t.string   "name"
    t.string   "keypad_1"
    t.string   "keypad_2"
    t.string   "keypad_3"
    t.string   "keypad_4"
    t.string   "keypad_5"
    t.string   "keypad_6"
    t.string   "keypad_7"
    t.string   "keypad_8"
    t.string   "keypad_9"
    t.string   "keypad_0"
    t.datetime "created_at"
    t.datetime "updated_at"
    t.integer  "user_id"
    t.integer  "active",      :limit => 1, :default => 1
    t.integer  "script_id"
  end

  create_table "campaigns_voter_lists", :id => false, :force => true do |t|
    t.integer "campaign_id"
    t.integer "voter_list_id"
  end

  create_table "lists", :force => true do |t|
    t.string   "name"
    t.integer  "group_id"
    t.integer  "user_id"
    t.datetime "created_at"
    t.datetime "updated_at"
  end

  create_table "scripts", :force => true do |t|
    t.string   "name"
    t.integer  "user_id"
    t.integer  "active",     :limit => 1, :default => 1
    t.text     "script"
    t.string   "keypad_1"
    t.string   "keypad_2"
    t.string   "keypad_3"
    t.string   "keypad_4"
    t.string   "keypad_5"
    t.string   "keypad_6"
    t.string   "keypad_7"
    t.string   "keypad_8"
    t.string   "keypad_9"
    t.string   "keypad_10"
    t.string   "keypad_11"
    t.string   "keypad_12"
    t.string   "keypad_13"
    t.string   "keypad_14"
    t.string   "keypad_15"
    t.string   "keypad_16"
    t.string   "keypad_17"
    t.string   "keypad_18"
    t.string   "keypad_19"
    t.string   "keypad_20"
    t.string   "keypad_21"
    t.string   "keypad_22"
    t.string   "keypad_23"
    t.string   "keypad_24"
    t.string   "keypad_25"
    t.string   "keypad_26"
    t.string   "keypad_27"
    t.string   "keypad_28"
    t.string   "keypad_29"
    t.string   "keypad_30"
    t.string   "keypad_31"
    t.string   "keypad_32"
    t.string   "keypad_33"
    t.string   "keypad_34"
    t.string   "keypad_35"
    t.string   "keypad_36"
    t.string   "keypad_37"
    t.string   "keypad_38"
    t.string   "keypad_39"
    t.string   "keypad_40"
    t.string   "keypad_41"
    t.string   "keypad_42"
    t.string   "keypad_43"
    t.string   "keypad_44"
    t.string   "keypad_45"
    t.string   "keypad_46"
    t.string   "keypad_47"
    t.string   "keypad_48"
    t.string   "keypad_49"
    t.string   "keypad_50"
    t.string   "keypad_51"
    t.string   "keypad_52"
    t.string   "keypad_53"
    t.string   "keypad_54"
    t.string   "keypad_55"
    t.string   "keypad_56"
    t.string   "keypad_57"
    t.string   "keypad_58"
    t.string   "keypad_59"
    t.string   "keypad_60"
    t.string   "keypad_61"
    t.string   "keypad_62"
    t.string   "keypad_63"
    t.string   "keypad_64"
    t.string   "keypad_65"
    t.string   "keypad_66"
    t.string   "keypad_67"
    t.string   "keypad_68"
    t.string   "keypad_69"
    t.string   "keypad_70"
    t.string   "keypad_71"
    t.string   "keypad_72"
    t.string   "keypad_73"
    t.string   "keypad_74"
    t.string   "keypad_75"
    t.string   "keypad_76"
    t.string   "keypad_77"
    t.string   "keypad_78"
    t.string   "keypad_79"
    t.string   "keypad_80"
    t.string   "keypad_81"
    t.string   "keypad_82"
    t.string   "keypad_83"
    t.string   "keypad_84"
    t.string   "keypad_85"
    t.string   "keypad_86"
    t.string   "keypad_87"
    t.string   "keypad_88"
    t.string   "keypad_89"
    t.string   "keypad_90"
    t.string   "keypad_91"
    t.string   "keypad_92"
    t.string   "keypad_93"
    t.string   "keypad_94"
    t.string   "keypad_95"
    t.string   "keypad_96"
    t.string   "keypad_97"
    t.string   "keypad_98"
    t.string   "keypad_99"
    t.datetime "created_at"
    t.datetime "updated_at"
  end

  create_table "seos", :force => true do |t|
    t.string   "action"
    t.string   "controller"
    t.string   "crmkey"
    t.string   "title"
    t.string   "keywords"
    t.string   "description"
    t.text     "content",     :limit => 16777215
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
    t.string   "password"
    t.datetime "created_at"
    t.datetime "updated_at"
  end

  create_table "voter_lists", :force => true do |t|
    t.string   "name"
    t.string   "user_id"
    t.boolean  "active",     :default => true
    t.datetime "created_at"
    t.datetime "updated_at"
  end

  create_table "voter_results", :force => true do |t|
    t.integer  "caller_id"
    t.integer  "voter_id"
    t.integer  "campaign_id"
    t.string   "status",      :default => "not called"
    t.string   "result"
    t.integer  "duration"
    t.datetime "start_time"
    t.datetime "end_time"
    t.string   "guid"
    t.datetime "created_at"
    t.datetime "updated_at"
  end

  create_table "voters", :force => true do |t|
    t.string   "Phone"
    t.string   "CustomID"
    t.string   "LastName"
    t.string   "FirstName"
    t.string   "MiddleName"
    t.string   "Suffix"
    t.string   "Email"
    t.integer  "campaign_id"
    t.boolean  "active",        :default => true
    t.datetime "created_at"
    t.integer  "voter_list_id"
    t.datetime "updated_at"
    t.integer  "user_id"
    t.string   "status",        :default => "not called"
    t.string   "result"
  end

end
