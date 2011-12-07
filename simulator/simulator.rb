require 'active_record'
require "ostruct"
require 'yaml'
RAILS_ENV = ENV['RAILS_ENV']

def database_settings
  yaml_file = File.open(File.join(File.dirname(__FILE__), 'database.yml'))
  yaml = YAML.load(yaml_file)
  @plugins ||= yaml[RAILS_ENV || 'development']
end

ActiveRecord::Base.establish_connection(
  :adapter  => database_settings['adapter'],
  :database => database_settings['database'],
  :username => database_settings['username'],
  :password => database_settings['password'].blank? ? nil : database_settings['password'],
  :host     => database_settings['host']
)

class CallerSession < ActiveRecord::Base
end

class CallAttempt < ActiveRecord::Base
  def duration
    return nil unless call_start
    ((call_end || Time.now) - self.call_start).to_i
  end
end

class SimulatedValues < ActiveRecord::Base
end

class CallerStatus
  attr_accessor :status
  def initialize(status)
    @status = status
  end

  def available?
    @status == 'available'
  end

  def unavailable?
    !available?
  end

  def toggle
    @status = available? ? 'busy' : 'available'
  end
end

def average(array)
  array.sum.to_f / array.size
end

target_abandonment = 0.1
start_time = 60 * 10
simulator_length = 60 * 60
campaign_id = 106
abandon_count = 0

caller_statuses = CallerSession.where(:campaign_id => campaign_id, :on_call => true).size.times.map{ CallerStatus.new('available') }
caller_statuses = 10.times.map{ CallerStatus.new('available') }

call_attempts = CallAttempt.where(:campaign_id => campaign_id)
recent_call_attempts = call_attempts.where(:status => "Call completed with success.").map{|attempt| OpenStruct.new(:length => attempt.duration, :counter => 0)}

puts call_attempts.map(&:status)
recent_dials = call_attempts.map{|attempt| OpenStruct.new(:length => rand(15), :counter => 0, :answered? => attempt.status == 'Call completed with success.') }
puts recent_call_attempts, recent_dials

alpha = 0.01
beta = 0.0

best_alpha = 0.01
best_beta = 1
best_utilisation = 0

while beta < 1
  idle_time = 0
  active_time = 0
  active_dials = []
  active_dials << recent_dials[rand(recent_dials.size)]
  finished_dials = []
  active_call_attempts = []
  finished_call_attempts = []

  t = 0

  while(t <= simulator_length)
    active_call_attempts.clone.each do |call_attempt|
      if call_attempt.counter == call_attempt.length
        caller_statuses.detect(&:unavailable?).toggle
        finished_call_attempts << call_attempt
        active_call_attempts.delete(call_attempt)
        call_attempt.counter = 0
      else
        call_attempt.counter += 1
      end
    end

    active_dials.clone.each do |dial|
      if dial.counter == dial.length
        if dial.answered?
          if status = caller_statuses.detect(&:available?)
            status.toggle
            active_call_attempts << recent_call_attempts[rand(recent_call_attempts.size)]
          else
            abandon_count += 1
          end
        end
        finished_dials << dial
        active_dials.delete(dial)
        dial.counter = 0
      else
        dial.counter += 1
      end
    end

    dials_made = finished_dials.select{|dial| dial.counter < start_time}
    dials_answered = finished_dials.select{|dial| dial.counter < start_time && dial.answered?}
    dials_needed = dials_made.empty? ? 0 : ((alpha * dials_answered.size).to_f / dials_made.size).to_i
    mean_call_length = average(dials_made.map(&:length))
    longest_call_length = dials_made.empty? ? 10.minutes : dials_made.map(&:length).inject(dials_made.first.length){|champion, challenger| [champion, challenger].max}
    expected_call_length = (1 - beta) * mean_call_length + beta * longest_call_length
    available_callers = caller_statuses.select(&:available?).size +
      active_call_attempts.select{|call_attempt| call_attempt.counter > expected_call_length}.size -
      active_call_attempts.select{|call_attempt| call_attempt.counter > longest_call_length}.size
    ringing_lines = active_dials.size
    dials_to_make = (dials_needed * available_callers) - ringing_lines
    dials_to_make.times{ active_dials << recent_dials[rand(dials_to_make.size)] }
    idle_time += caller_statuses.select(&:available?).size
    active_time += caller_statuses.select(&:unavailable?).size
    finished_dials.each{|dial| dial.counter += 1}
    finished_call_attempts.each{|call_attempt| call_attempt.counter += 1}
    t += 1
  end
  answered_finished_dials = finished_dials.select(&:answered?)
  simulated_abandonment = answered_finished_dials.empty? ? 0 : (abandon_count.to_f / answered_finished_dials.size)
  puts "simulated_abandonment: #{simulated_abandonment}"

  if simulated_abandonment <= target_abandonment
    total_time = (active_time + idle_time)
    puts active_time, idle_time
    utilisation = total_time == 0 ? 0 : active_time.to_f / total_time
    if utilisation > best_utilisation
      best_alpha = alpha
      best_beta = beta
      best_utilisation = utilisation
    end
  end
  if alpha < 1
    alpha += 0.10
  else
    alpha = 0.00
    beta += 0.10
  end
  puts "alpha: #{alpha} & beta: #{beta} with utilisation: #{utilisation}"
  puts "best utilisation so far: #{best_utilisation} and abandonment: #{simulated_abandonment}"
end

SimulatedValues.find_or_create_by_campaign_id(campaign_id).update_attributes(:alpha => best_alpha, :beta => best_beta)
puts best_alpha, best_beta
