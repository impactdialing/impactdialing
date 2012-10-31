require 'rubygems'
require 'active_record'
require 'active_support/all'
require 'mysql2'

class CallersStatistics < Scout::Plugin

  def build_report
    ActiveRecord::Base.establish_connection(:adapter => 'mysql2', 
                                            :database => "heroku_production",
                                            :host => "heroku-production55-read.cjo94dhm4pos.us-east-1.rds.amazonaws.com",
                                            :username => 'root',
                                            :password => "pfsdh37sl203jq")
    
    beginning_of_day = Time.now.beginning_of_day + 8.hours
    puts beginning_of_day
    success_calls_without_answers_sql = "SELECT count(call_attempts.id) FROM call_attempts  
           LEFT JOIN answers on answers.call_attempt_id = call_attempts.id  
           LEFT JOIN note_responses on note_responses.call_attempt_id = call_attempts.id  
           WHERE note_responses.id is null and answers.id is null 
             AND status = 'Call completed with success.'    
             AND voter_response_processed = 1  
             AND call_attempts.created_at > '#{beginning_of_day.to_s(:db)}'"
    success_calls_without_answers = ActiveRecord::Base.connection.select_value(success_calls_without_answers_sql)
    
    report( :success_calls_without_answers =>   success_calls_without_answers)
  rescue => error_message
    error "Couldn't parse output. Make sure you have proper SQL. #{error_message}"
  end

end