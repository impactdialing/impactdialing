require 'active_record'
require "ostruct"

ActiveRecord::Base.establish_connection(
  :adapter  => 'jdbcmysql',
  :database => 'impactdialing_dev',
  :username => 'root',
  :password => nil,
  :host     => 'localhost')

class CallerSession < ActiveRecord::Base
end

class CallAttempt < ActiveRecord::Base
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
campaign_id = 1

caller_statuses = CallerSession.where(:campaign_id => campaign_id, :on_call => true).size.times.map{ CallerStatus.new('available') }

call_attempts = CallAttempt.where(:campaign_id => campaign_id)
recent_call_attempts = call_attempts.where(:status => "Call completed with success.").map{|attempt| OpenStruct.new(:length => attempt.duration, :counter => 0)}

recent_dials = call_attempts.map{|attempt| OpenStruct.new(:dial_time => rand(15), :counter => 0, :answered? => attempt.status != 'Call cancelled') }

alpha = 0.01
beta = 0.0

best_alpha = 0.01
best_beta = 1
best_utilization = 0

while beta < 1
  idle_time = 0
  active_time = 0
  active_dials = []
  finished_dials = []
  active_call_attempts = []
  finished_call_attempts = []

  t = 0

  while(t <= simulator_length)
    active_call_attempts.clone.each do |call_attempt|
      if call_attempt.counter == call_attempt.length
        caller_statuses.detect(&:available?).toggle
        finished_call_attempts << call_attempt
        active_call_attempts.drop(call_attempt)
        call_attempt.counter = 0
      else
        call_attempt.counter += 1
      end
    end

    active_dials.clone.each do |dial|
      if dial.counter == dial.length
        if dial.answered?
          if status = caller_statuses.detect(&:unavailable?)
            status.toggle
            active_call_attempts = recent_call_attempts[rand(recent_call_attempts.size)]
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
    dials_needed = alpha * dials_answered.size / dials_made.size
    mean_call_length = average(dials_made.map(&:length))
    longest_call_length = dials_made.map(&:length).inject([dials_made.first.length]){|champion, challenger| [champion, challenger].max}
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
  simulated_abandonment = abandon_count / finished_dials.select(&:answered?).size

  if simulated_abandonment <= target_abandonment
    utilization = active_time / (active_time + idle_time)
    if utilization > best_utilization
      best_alpha = alpha
      best_beta = beta
    end
  end
  if alpha < 1
    alpha += 0.01
  else
    alpha = 0.01
    beta += 0.01
  end
end

