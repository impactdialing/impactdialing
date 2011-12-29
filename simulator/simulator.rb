require 'active_record'
require "ostruct"
require 'yaml'
require 'logger'
require 'fileutils'

RAILS_ROOT = File.expand_path('../..', __FILE__)
require File.join(RAILS_ROOT, 'config/environment')
SIMULATOR_ROOT = ENV['SIMULATOR_ROOT'] || File.expand_path('..', __FILE__)
FileUtils.mkdir_p(File.join(SIMULATOR_ROOT, 'log'), :verbose => true)
ActiveRecord::Base.logger = Logger.new(File.open(File.join(SIMULATOR_ROOT, 'log', "simulator_#{RAILS_ENV}.log"), 'a'))

#def database_settings
#  yaml_file = File.open(File.join(File.dirname(__FILE__), '../config/database.yml'))
#  yaml = YAML.load(yaml_file)
#  @plugins ||= yaml[RAILS_ENV].tap{|y| ActiveRecord::Base.logger.info y}
#end
#
#ActiveRecord::Base.establish_connection(
#  :adapter  => database_settings['adapter'],
#  :database => database_settings['database'],
#  :username => database_settings['username'],
#  :password => database_settings['password'].blank? ? nil : database_settings['password'],
#  :host     => database_settings['host']
#)

class CallerSession < ActiveRecord::Base
end

class CallAttempt < ActiveRecord::Base
  def duration
    return nil unless call_start
    ((wrapup_time || Time.now) - self.call_start).to_i
  end

  def ringing_duration
    return 15 unless connecttime
    (connecttime - created_at).to_i
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

def simulate(campaign_id)
  target_abandonment = Campaign.find(campaign_id).acceptable_abandon_rate
  start_time = 60 * 10
  simulator_length = 60 * 60
  abandon_count = 0

  caller_statuses = CallerSession.where(:campaign_id => campaign_id,
            :on_call => true).size.times.map{ CallerStatus.new('available') }
  #caller_statuses = 10.times.map{ CallerStatus.new('available') }

  call_attempts = CallAttempt.where(:campaign_id => campaign_id)
  recent_call_attempts = call_attempts.where(:status => "Call completed with success.").map{|attempt| OpenStruct.new(:length => attempt.duration, :counter => 0)}

  ActiveRecord::Base.logger.info call_attempts.map(&:status)
  recent_dials = call_attempts.map{|attempt| OpenStruct.new(:length => attempt.ringing_duration, :counter => 0, :answered? => attempt.status == 'Call completed with success.') }
  ActiveRecord::Base.logger.info recent_call_attempts
  ActiveRecord::Base.logger.info recent_dials

  alpha = 0.01
  beta = 0.0

  best_alpha = 0.01
  best_beta = 1
  best_utilisation = 0

  if recent_call_attempts.empty? || recent_dials.empty?
    SimulatedValues.find_or_create_by_campaign_id(campaign_id, :alpha => best_alpha, :beta => best_beta)
    return
  end

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
      dials_answered = dials_made.select(&:answered?)
      mean_call_length = average(dials_made.map(&:length))
      dials_needed = dials_made.empty? ? 0 : ((alpha * dials_made.size).to_f / dials_answered.size)
      longest_call_length = dials_made.empty? ? 10.minutes : dials_made.map(&:length).inject(dials_made.first.length){|champion, challenger| [champion, challenger].max}
      expected_call_length = (1 - beta) * mean_call_length + beta * longest_call_length
      available_callers = caller_statuses.select(&:available?).size +
        active_call_attempts.select{|call_attempt| call_attempt.counter > expected_call_length}.size -
        active_call_attempts.select{|call_attempt| call_attempt.counter > longest_call_length}.size
      ringing_lines = active_dials.size
      dials_to_make = (dials_needed * available_callers) - ringing_lines

      dials_to_make.times{ active_dials << recent_dials[rand(recent_dials.size)] }
      idle_time += caller_statuses.select(&:available?).size
      active_time += caller_statuses.select(&:unavailable?).size
      finished_dials.each{|dial| dial.counter += 1}
      finished_call_attempts.each{|call_attempt| call_attempt.counter += 1}
      t += 1
    end

    answered_finished_dials = finished_dials.select(&:answered?)
    simulated_abandonment = answered_finished_dials.empty? ? 0 : (abandon_count.to_f / answered_finished_dials.size)
    ActiveRecord::Base.logger.info "simulated_abandonment: #{simulated_abandonment}"

    if simulated_abandonment <= target_abandonment
      total_time = (active_time + idle_time)
      ActiveRecord::Base.logger.info "active_time: #{active_time}, idle_time: #{idle_time}"
      utilisation = total_time == 0 ? 0 : active_time.to_f / total_time
      if utilisation > best_utilisation
        best_alpha = alpha
        best_beta = beta
        best_utilisation = utilisation
        simulated_abandonment_for_best_utilisation = simulated_abandonment
      end
    end
    if alpha < 1
      alpha += 0.10
    else
      alpha = 0.00
      beta += 0.10
    end
    ActiveRecord::Base.logger.info "alpha: #{alpha} & beta: #{beta} with utilisation: #{utilisation}"
    ActiveRecord::Base.logger.info "best utilisation so far: #{best_utilisation} and abandonment: #{simulated_abandonment}"
  end

  SimulatedValues.find_or_create_by_campaign_id(campaign_id).update_attributes(:alpha => best_alpha, :beta => best_beta)
  ActiveRecord::Base.logger.info "alpha: #{best_alpha} beta: #{best_beta} with utilisation: #{best_utilisation} and simulated abandonment: #{simulated_abandonment_for_best_utilisation}"
end

loop do
  begin
    CallerSession.where(:on_call => true).tap{|sessions| ActiveRecord::Base.logger.info sessions.size}.each do |c|
      simulate(c.campaign_id)
    end
    sleep 3
  rescue Exception => e
    if e.class == SystemExit || e.class == Interrupt
      ActiveRecord::Base.logger.info "============ EXITING  ============"
      exit
    end
    ActiveRecord::Base.logger.info "Rescued - #{ e } (#{ e.class })!"
    ActiveRecord::Base.logger.info e.backtrace
  end
end
