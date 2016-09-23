# todo: extract simulation itself into a separate Simulation PORO
# leaving only the setup and persistence here
require 'octopus'

class SimulatedValues < ActiveRecord::Base
  attr_accessor :best_utilization

  belongs_to :campaign
  validates :campaign, presence: true
  before_save :calculate_values

  START_TIME = 30.minutes.ago
  SIMULATION_LENGTH = 4.minutes
  INCREMENT = 6
  CALL_ATTEMPT_LIMIT = 100

  def calculate_values
    if number_of_callers_on_call < 5 || recent_call_attempts.size < 50
      self.best_dials = 1
      self.best_wrapup_time = 1000
      return
    end

    simulated_callers = simulated_callers(number_of_callers_on_call)
    simulated_call_attempts = simulated_call_attempts(recent_call_attempts)

    answer_rate = answer_rate(simulated_call_attempts)
    longest_wrapup = longest_wrapup(simulated_call_attempts)

    set_default_best_values(longest_wrapup)

    loop_through_all_increments(INCREMENT, longest_wrapup, answer_rate, simulated_callers, simulated_call_attempts, campaign.acceptable_abandon_rate)
  end

  def loop_through_all_increments(increment, longest_wrapup, answer_rate, simulated_callers, simulated_call_attempts, acceptable_abandon_rate)
    # since we don't currently track wrapup time, no use simulating on it
    # (1..increment).each do |current_increment|
      # current_wrapup = current_wrapup(longest_wrapup, current_increment, increment)
      current_wrapup = longest_wrapup
      (1..increment).each do |current_increment|
        current_dials = current_dials(answer_rate, current_increment, increment)
        simulate!(simulated_callers, simulated_call_attempts, current_dials, current_wrapup, SIMULATION_LENGTH)
        update_best_parameters!(simulated_callers, simulated_call_attempts, campaign.acceptable_abandon_rate, current_dials, current_wrapup)
        reset_simulated_caller_stats(simulated_callers)
        reset_simulated_call_attempt_stats(simulated_call_attempts)
      end
    # end
  end

  def simulate!(simulated_callers, simulated_call_attempts, current_dials, current_wrapup, simulation_length)
    simulation_length.times do |seconds|
      # puts(simulated_callers.map(&:state).uniq.map do |state|
      #   simulated_callers.count {|sc| sc.state == state}.to_s + ' callers ' + state.to_s
      # end.join(', '))
      simulated_callers.each do |sc|
        sc.forward_one_second
      end
      # puts(simulated_call_attempts.map(&:state).uniq.map do |state|
      #   simulated_call_attempts.count {|sc| sc.state == state}.to_s + ' calls ' + state.to_s
      # end.join(', '))
      simulated_call_attempts.each do |sca|
        sca.forward_one_second
      end
      lines_to_dial = lines_to_dial(simulated_callers, simulated_call_attempts, current_dials)
      make_dials(lines_to_dial, simulated_call_attempts)
      assign_answered_calls_to_callers(simulated_callers, simulated_call_attempts)
    end
  end

  def update_best_parameters!(simulated_callers, simulated_call_attempts, acceptable_abandon_rate, current_dials, current_wrapup)
    if acceptable_abandon_rate_not_exceeded?(simulated_call_attempts, acceptable_abandon_rate)
      current_utilization = utilization(simulated_callers)
      if current_utilization > self.best_utilization
        self.best_dials = current_dials
        self.best_wrapup_time = current_wrapup
        self.best_utilization = current_utilization
      end
    end
  end

  def number_of_callers_on_call
    @number_of_callers_on_call ||= campaign.caller_sessions.on_call.count
  end

  def simulated_callers(number_of_callers_on_call)
    simulated_callers = []
    number_of_callers_on_call.times {simulated_callers << SimulatedCaller.new}
    simulated_callers
  end

  def recent_call_attempts
    @recent_call_attempts ||= campaign.call_attempts.using(:simulator_slave).between(START_TIME, Time.now).limit(CALL_ATTEMPT_LIMIT)
  end

  def simulated_call_attempts(recent_call_attempts)
    recent_call_attempts.map do |call_attempt|
      SimulatedCallAttempt.from_call_attempt(call_attempt)
    end
  end

  def answer_rate(simulated_call_attempts)
    if simulated_call_attempts.any?
      simulated_call_attempts.count.to_f / simulated_call_attempts.count {|sca| sca.answered?}.to_f
    else
      1
    end
  end

  def longest_wrapup(simulated_call_attempts)
    simulated_call_attempts.map {|sca| sca.wrapup_length || 0}.sort.last
  end

  def set_default_best_values(longest_wrapup)
    self.best_dials = 1
    self.best_wrapup_time = longest_wrapup
    self.best_utilization = 0
  end

  def current_wrapup(longest_wrapup, current_increment, total_increment)
    longest_wrapup.to_f * (current_increment.to_f / total_increment.to_f)
  end

  def current_dials(answer_rate, current_increment, total_increment)
    current_dials = answer_rate.to_f * (current_increment.to_f / total_increment.to_f)
    if current_dials >= 1
      current_dials
    else
      1
    end
  end

  def lines_to_dial(simulated_callers, simulated_call_attempts, current_dials)
    on_hold_callers = simulated_callers.count {|simulated_caller| simulated_caller.state == 'on_hold'}
    ringing_lines = simulated_call_attempts.count {|call_attempt| call_attempt.state == 'ringing'}
    lines_to_dial = on_hold_callers * current_dials - ringing_lines
    if lines_to_dial > 0
      lines_to_dial
    else
      0
    end
  end

  def make_dials(lines_to_dial, simulated_call_attempts)
    idle_call_attempts = simulated_call_attempts.select {|call_attempt| call_attempt.state == 'idle'}
    dials = idle_call_attempts.sample(lines_to_dial).each {|call_attempt| call_attempt.dial}
  end

  def assign_answered_calls_to_callers(simulated_callers, simulated_call_attempts)
    on_hold_callers = simulated_callers.select {|sc| sc.state == 'on_hold'}
    simulated_call_attempts.each do |sca|
      if sca.just_answered?
        if on_hold_callers.any?
          sca.assign_caller(on_hold_callers.sample)
        else
          sca.abandon
        end
      end
    end
  end

  def reset_simulated_caller_stats(simulated_callers)
    simulated_callers.each {|sc| sc.reset_stats!}
  end

  def reset_simulated_call_attempt_stats(simulated_call_attempts)
    simulated_call_attempts.each {|sca| sca.reset_stats!}
  end

  def utilization(simulated_callers)
    total_on_call_time = 0
    total_on_hold_time = 0
    simulated_callers.each do |sc|
      total_on_call_time += sc.on_call_time
      total_on_hold_time += sc.on_hold_time
    end
    total_on_call_time.to_f / (total_on_call_time.to_f + total_on_hold_time.to_f)
  end

  def acceptable_abandon_rate_not_exceeded?(simulated_call_attempts, acceptable_abandon_rate)
    total_abandoned = simulated_call_attempts.inject(0) {|sum, sca| sum += sca.abandon_count}
    total_answered = simulated_call_attempts.inject(0) {|sum, sca| sum += sca.answer_count}
    simulated_abandon_rate = total_abandoned.to_f / total_answered.to_f
    simulated_abandon_rate < acceptable_abandon_rate
  end
end

# ## Schema Information
#
# Table name: `simulated_values`
#
# ### Columns
#
# Name                        | Type               | Attributes
# --------------------------- | ------------------ | ---------------------------
# **`id`**                    | `integer`          | `not null, primary key`
# **`campaign_id`**           | `integer`          |
# **`created_at`**            | `datetime`         |
# **`updated_at`**            | `datetime`         |
# **`best_dials`**            | `float`            |
# **`best_conversation`**     | `float`            |
# **`longest_conversation`**  | `float`            |
# **`best_wrapup_time`**      | `float`            |
#
