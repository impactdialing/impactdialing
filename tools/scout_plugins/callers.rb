
require 'set'
require 'rubygems'
require 'active_record'
require 'active_support/all'
require 'mysql2'

class CallerSession < ActiveRecord::Base
  scope :on_call, :conditions => {:on_call => true}
end

class CallAttempt < ActiveRecord::Base
end

class CallersStatistics < Scout::Plugin

  def build_report
    ActiveRecord::Base.establish_connection(:adapter => 'mysql2', 
                                            :database => "heroku_production",
                                            :host => "heroku-production55-read.cjo94dhm4pos.us-east-1.rds.amazonaws.com",
                                            :username => 'root',
                                            :password => "pfsdh37sl203jq")
    beginning_of_day = Time.now.beginning_of_day + 8.hours
    puts beginning_of_day
    report( :callers_count =>   CallerSession.on_call.count,
            :calls_daily_total => CallAttempt.where("created_at > '#{beginning_of_day.to_s(:db)}'").count )
  rescue => error_message
    error "Couldn't parse output. Make sure you have proper SQL. #{error_message}"
  end

end