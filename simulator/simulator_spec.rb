require 'active_record'
require "ostruct"
require 'yaml'
require 'logger'
require 'fileutils'

RAILS_ROOT = File.expand_path('../..', __FILE__)
require File.join(RAILS_ROOT, 'config/environment')

def simulator_test
  campaign = Campaign.create({:name => 'a campaign', :caller_id => '1234567890', :account => Account.create,
                              :recycle_rate => 1, :start_time => Time.new(2011,1,1,1,0,0), :end_time => Time.new(2011,1,1,23,0,0),
                              :time_zone => "Pacific Time (US & Canada)", :acceptable_abandon_rate => 0.1})
  25.times{CallerSession.create(:available_for_call => true, :on_call => true, :campaign_id => campaign.id)}
  call_time = 8.minutes.ago
  connect_times = []
  answer_statuses = []
  conversation_times = []

  CSV.foreach('/home/preethi/callCenter/outgoingData.csv') do |row|
    connect_times << row[0].to_i
    answer_statuses << row[1].to_i
  end

  CSV.foreach('/home/preethi/callCenter/activeData.csv') do |row|
    conversation_times << row[0].to_i
  end


  connect_times.size.times do |index|
    created_at = call_time - connect_times[index]
    wrapup_time = call_time + 5
    start_time = connect_time = call_time
    if answer_statuses[index] == 1
      call_status = CallAttempt::Status::SUCCESS
      wrapup_time = call_time + conversation_times[index]
    else
      call_status = CallAttempt::Status::NOANSWER
    end
    CallAttempt.create(:created_at => created_at, :connecttime => connect_time, :call_start => start_time, :wrapup_time => wrapup_time, :status => call_status, :campaign => campaign)
  end
end

simulator_test