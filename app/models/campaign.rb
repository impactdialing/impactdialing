require Rails.root.join("lib/twilio_lib")

class Campaign < ActiveRecord::Base
  include Deletable
  include ApplicationHelper::TimeUtils
  include ReportsHelper::Utilization
  include ReportsHelper::Billing

  has_many :caller_sessions
  has_many :voter_lists, :conditions => {:active => true}
  has_many :all_voters, :class_name => 'Voter'
  has_many :call_attempts
  has_many :transfer_attempts
  has_many :callers
  has_one :simulated_values
  has_many :answers
  has_many :call_responses
  belongs_to :script
  belongs_to :voicemail_script, :class_name => 'Script', :foreign_key => 'voicemail_script_id'
  belongs_to :account
  belongs_to :recording

  delegate :questions_and_responses, :to => :script

  scope :robo, :conditions => {:robo => true}
  scope :manual, :conditions => {:robo => false}
  scope :for_account, lambda { |account| {:conditions => ["account_id = ?", account.id]} }
  scope :with_running_caller_sessions, {
      :select => "distinct campaigns.*",
      :joins => "inner join caller_sessions on (caller_sessions.campaign_id = campaigns.id)",
      :conditions => {"caller_sessions.on_call" => true}
  }
  scope :using_web_ui, :conditions => {:use_web_ui => true}
  scope :for_caller, lambda { |caller| {:include => [:caller_sessions], :conditions => {"caller_sessions.caller_id" => caller.id}}}

  before_create :create_uniq_pin

  attr_accessor :predictive_alpha, :predictive_beta

  validates :name, :presence => true
  validates :caller_id, :presence => true, :unless => :new_campaign
  validates :caller_id, :numericality => {:on => :update}, :length => {:on => :update, :minimum => 10, :maximum => 10}, :unless => Proc.new{|campaign| campaign.caller_id && campaign.caller_id.start_with?('+')}
  validate :set_caller_id_error_msg
  validate :predictive_type_change
  cattr_reader :per_page
  @@per_page = 25

  before_validation :set_untitled_name
  before_save :set_untitled_name
  #before_save :set_answering_machine_detect
  before_validation :sanitize_caller_id

  module Type
    PREVIEW = "preview"
    PREDICTIVE = "algorithm1"
    PROGRESSIVE = "progressive"
  end

  def new_campaign
    new_record?
  end

  def set_caller_id_error_msg
      if errors[:caller_id].any?
        errors.add(:base, 'Your Caller ID must be a 10-digit North American phone number or begin with "+" and the country code.')
        errors[:caller_id].clear
      end
    end

  def set_caller_id_error_msg
    if errors[:caller_id].any?
      errors.add(:base, 'Your Caller ID must be a 10-digit North American phone number or begin with "+" and the country code.')
      errors[:caller_id].clear
    end
  end

  def predictive_type_change
    if predictive_type_changed? && callers_log_in?
      errors.add(:base, 'You cannot change dialing modes while callers are logged in.')
    end
  end


  def predictive_type_change
     if predictive_type_changed? && callers_log_in?
       errors.add(:base, 'You cannot change dialing modes while callers are logged in.')
     end
   end

  def is_preview_or_progressive
    predictive_type == Type::PREVIEW || predictive_type == Type::PROGRESSIVE
  end

  def set_untitled_name
    self.name = "Untitled #{account.campaigns.count + 1}" if self.name.blank?
  end

  def sanitize_caller_id
    self.caller_id = Voter.sanitize_phone(self.caller_id)
  end

  def create_uniq_pin
    pin = nil

    loop do
      pin = rand.to_s[2..6]
      break unless Campaign.find_by_campaign_id(pin)
    end
    self.campaign_id = pin
  end

  def set_answering_machine_detect
    self.answering_machine_detect = self.use_recordings = self.robo? && !self.voicemail_script.nil?
  end

  def disable_voter_list
    voter_lists.each do |voter_list|
      voter_list.enabled = false
      voter_list.save
    end
  end

  def leave_voicemail?
     self.robo? && self.voicemail_script
  end

  def time_period_exceed?
    if start_time.hour < end_time.hour
      !(start_time.hour <= Time.now.utc.in_time_zone(time_zone).hour && end_time.hour > Time.now.utc.in_time_zone(time_zone).hour)
    else
      !(start_time.hour >= Time.now.utc.in_time_zone(time_zone).hour || end_time.hour < Time.now.utc.in_time_zone(time_zone).hour)
    end
  end

  def oldest_available_caller_session
    caller_sessions.available.find(:first, :order => "updated_at ASC")
  end

  def recent_attempts(mins=10)
    attempts = CallAttempt.find_all_by_campaign_id(self.id, :conditions=>"call_start > DATE_SUB(now(),INTERVAL #{mins} MINUTE)", :order=>"id desc")
  end

  def callers_log_in?
    caller_sessions.on_call.length > 0
  end

  def end_all_calls(account, auth, appurl)
    in_progress = CallAttempt.find_all_by_campaign_id(self.id, :conditions=>"sid is not null and call_end is null and id > 45")
    in_progress.each do |attempt|
      t = TwilioLib.new(account, auth)
      a=t.call("POST", "Calls/#{attempt.sid}", {'CurrentUrl'=>"#{appurl}/callin/voterEndCall?attempt=#{attempt.id}"})
      attempt.call_end=Time.now
      attempt.save
    end
    in_progress
  end

  def end_all_callers(account, auth, appurl)
    in_progress = CallerSession.find_all_by_campaign_id(self.id, :conditions=>"on_call=1")
    in_progress.each do |caller|
      t = TwilioLib.new(account, auth)
      a=t.call("POST", "Calls/#{caller.sid}", {'CurrentUrl'=>"#{appurl}/callin/callerEndCall?session=#{caller.id}"})
      if a.index("RestException")
        caller.on_call=false
        caller.save
      end
    end
    in_progress
  end

  def calls_in_ending_window(period=10, predictive_type="longest")
      #calls predicted to end soon
      stats = self.call_stats(period)
      if predictive_type=="longest"
        window = stats[:biggest_long]
      else
        window = stats[:avg_long]
      end
      window = window - 10 if window > 10
  #   Rails.logger.debug("window: #{window}")
      ending = CallAttempt.all(:conditions=>"
      campaign_id=#{self.id}
      and status like'Connected to caller%'
      and timediff(now(),call_start) >SEC_TO_TIME(#{window})
      ")
      ending
    end

  def call_stats(mins=nil)
     @stats ||= {:attempts=>[], :abandon=>0, :answer=>0, :no_answer=>0,
                 :total=>0, :answer_pct=>0, :avg_duration=>0, :abandon_pct=>0,
                 :avg_hold_time=>0, :total_long=>0, :total_short=>0, :avg_long=>0,
                 :biggest_long=>0, :avg_ring_time=>0, :avg_ring_time_devation=>0,
                 :current_short=>0, :current_long=>0,
                 :short_deviation=>0, :avg_short=>0}.tap do |stats|
       totduration=0
       tothold=0
       totholddata=0
       totlongduration=0
       totshortduration=0
       totringtime=0
       totringattempts=0
       ringattempts=[]
       longattempts=[]
       shortattempts=[]
       stats[:short_time] = 15
   
       if mins.blank?
         attempts = CallAttempt.find_all_by_campaign_id(self.id, :order=>"id desc")
       else
         attempts = CallAttempt.find_all_by_campaign_id(self.id,:conditions=>"call_start > DATE_SUB(now(),INTERVAL #{mins} MINUTE) or call_end > DATE_SUB(now(),INTERVAL #{mins} MINUTE)", :order=>"id desc")
       end
   
       stats[:attempts]=attempts
   
       attempts.each do |attempt|
   
         if attempt.status=="Call completed with success." || attempt.status.index("Connected to") #  || attempt.status=="Call in progress"
           stats[:answer] = stats[:answer]+1
           if attempt.ring_time!=nil
             totringtime=totringtime+attempt.ring_time
             totringattempts+=1
             ringattempts << attempt.ring_time
           end
         elsif attempt.status=="Call abandoned"
           stats[:abandon] = stats[:abandon]+1
         else
           stats[:no_answer] = stats[:no_answer]+1
         end
   
         stats[:total] = stats[:total]+1
   
         if attempt.status.index("Connected to") && attempt.duration!=nil
           if attempt.duration > stats[:short_time]
             stats[:current_long]=stats[:current_long]+1
           else
             stats[:current_short]=stats[:current_short]+1
           end
         end
   
   
         if attempt.duration!=nil && attempt.duration>0
           totduration = totduration + attempt.duration
           if attempt.duration <= stats[:short_time]
             stats[:total_short] = stats[:total_short]+1
             totshortduration = totshortduration + attempt.duration
             shortattempts<<attempt.duration.to_i
           else
             stats[:total_long] = stats[:total_long]+1
             totlongduration = totlongduration + attempt.duration
             longattempts<<attempt.duration.to_i
             stats[:biggest_long] = attempt.duration if attempt.duration > stats[:biggest_long]
           end
         end
   
         if !attempt.caller_hold_time.blank?
           tothold = tothold + attempt.caller_hold_time
           totholddata+=1
         end
       end
       #    avg_hold_time
       stats[:answer_pct] = (stats[:answer].to_f + stats[:abandon].to_f)/ stats[:total].to_f if stats[:total] > 0
       stats[:abandon_pct] = stats[:abandon].to_f / (stats[:answer].to_f + stats[:abandon].to_f) if stats[:answer] > 0
       stats[:avg_duration] = totduration / stats[:answer].to_f if stats[:answer] > 0
       stats[:avg_hold_time] = tothold/ totholddata if totholddata> 0
       stats[:avg_long] = totlongduration / stats[:total_long] if stats[:total_long] > 0
       stats[:avg_short] = totshortduration / stats[:total_short] if stats[:total_short] > 0
       stats[:avg_ring_time] = totringtime/totringattempts if totringattempts >0
       stats[:avg_ring_time_deviation] = self.std_deviation(ringattempts)
       stats[:long_deviation] = self.std_deviation(longattempts)
       stats[:short_deviation] = self.std_deviation(shortattempts)
       stats[:answer_plus_abandon_ct] = (stats[:abandon].to_f + stats[:answer].to_f) / stats[:total].to_f if stats[:total] > 0
   
   
       #new algo stuff
       if stats[:answer_plus_abandon_ct] ==nil
         stats[:dials_needed] = 2
       else
         dials = 1 / stats[:answer_plus_abandon_ct]
         dials = 2 if dials.infinite?
         dials = dials.to_f.round
         dials = self.max_calls_per_caller if dials > self.max_calls_per_caller
         dials = 2 if attempts.length < 50
         #      dials=1
         stats[:dials_needed] = dials
       end
       stats[:avg_ring_time_adjusted] = stats[:avg_ring_time] - (2*stats[:avg_ring_time_deviation])
       stats[:call_length_long] = stats[:avg_long] + (2*stats[:long_deviation])
       stats[:call_length_short] = stats[:avg_short] + (2*stats[:short_deviation])
   
       if stats[:total_long]==0 && stats[:total_short]==0
         stats[:ratio_short]=0
       elsif stats[:total_long]==0
         stats[:ratio_short]=1
       elsif stats[:total_short]==0
         stats[:ratio_short]=0
       else
         stats[:ratio_short] = stats[:total_short].to_f / (stats[:total_long] + stats[:total_short]).to_f
       end
       stats[:short_callers]= 1/(stats[:total_short].to_f / stats[:total_long].to_f).to_f
       #final calcs
       stats[:short_new_call_caller_threshold] = 1/(stats[:total_short].to_f / stats[:total_long].to_f).to_f
       stats[:short_new_call_time_threshold] = (stats[:avg_short] + (2*stats[:short_deviation])) - (stats[:avg_ring_time] - (2*stats[:avg_ring_time_deviation]))
       if self.predictive_type=="algorithm1"
         stats[:long_new_call_time_threshold] = (stats[:avg_long] + (2*stats[:long_deviation]))- (stats[:avg_ring_time] - (2*stats[:avg_ring_time_deviation]))
       else
         stats[:long_new_call_time_threshold] = stats[:avg_duration]
       end
   
       # bimodal pacing algorithm:
       # when stats[:short_new_call_caller_threshold] callers are on calls of length less than stats[:short_time]s, dial  stats[:dials_needed] lines at stats[:short_new_call_time_threshold]) seconds after the last call began.
       # if a call passes length 15s, dial stats[:dials_needed] lines at stats[:short_new_long_time_threshold]sinto the call.
   
     end
   end

  def voters_called
    Voter.find_all_by_campaign_id(self.id, :select=>"id", :conditions=>"status <> 'not called'")
  end


  def voters_count(status=nil, include_call_retries=true)
    active_lists = VoterList.find_all_by_campaign_id_and_active_and_enabled(self.id, 1, 1)
    return [] if active_lists.length==0
    active_list_ids = active_lists.collect { |x| x.id }
    Voter.find_all_by_active(1, :select=>"id", :conditions=>"voter_list_id in (#{active_list_ids.join(",")})  and (status='#{status}' OR (call_back=1 and last_call_attempt_time < (Now() - INTERVAL 180 MINUTE)) )")
  end


  def std_deviation(values)
    return 0 if values==nil || values.size==0
    begin
      count = values.size
      mean = values.inject(:+) / count.to_f
      stddev = Math.sqrt(values.inject(0) { |sum, e| sum + (e - mean) ** 2 } / count.to_f)
    rescue
#      Rails.logger.debug("deviation error: #{values.inspect}")
      return 0
    end
  end

  def voters(status=nil, include_call_retries=true, limit=300)
    voters_returned = []
    return voters_returned if !self.account.activated? || self.caller_id.blank?

    active_list_ids = VoterList.active_voter_list_ids(self.id)
    return voters_returned if active_list_ids.empty?

    voters_returned.concat(Voter.to_be_called(id, active_list_ids, status, recycle_rate))
    # voters_returned.concat(Voter.just_called_voters_call_back(self.id, active_list_ids)) if voters_returned.empty? && include_call_retries

    voters_returned.uniq
  end

   def answered_count(dialed_voters_ids)
     answers.count(:voter_id, :distinct => true, :conditions => ['voter_id in (?)',dialed_voters_ids])
   end


  def predictive_dial
    dial_predictive_voters
  end

  def callers_to_dial
    CallerSession.find_all_by_campaign_id_and_on_call(self.id, 1)
  end

  def callers_on_call
    CallerSession.find_all_by_campaign_id_and_on_call_and_available_for_call(self.id, 1, 0)
  end

  def callers_available_for_call
    CallerSession.find_all_by_campaign_id_and_on_call_and_available_for_call(self.id, 1, 1)
  end

  def call_attempts_in_progress
    call_attempts.dial_in_progress
  end

  def call_attempts_not_wrapped_up
    call_attempts.not_wrapped_up
  end

  def caller_sessions_in_progress
    caller_sessions.connected_to_voter
  end

  def callers_not_on_call
    callers.length - callers_on_call.length
  end

  def get_dial_ratio
    if self.predictive_type.index("power_")!=nil
      ratio_dial = self.predictive_type[6, 1].to_i
      DIALER_LOGGER.info "ratio_dial: #{ratio_dial}, #{callers.length}, #{predictive_type.index("power_")}"
    end
    ratio_dial
  end

  def num_short_calls_in_progress(short_threshold)
    #number of calls in progress of length less than stats[:short_time]
    short_counter=0

    callers_on_call.each do |session|
      if !session.attempt_in_progress.blank?
        attempt = CallAttempt.find(session.attempt_in_progress)
        if attempt.duration!=nil && attempt.duration < short_threshold
          short_counter+=1
        end
      end
    end
    short_counter
  end

  def determine_short_to_dial
    stats = call_stats(10)
    short_counter = num_short_calls_in_progress(stats[:short_time])
    if stats[:ratio_short]>0 && short_counter > 0
      max_short=(1/stats[:ratio_short]).round
      short_to_dial = (short_counter/max_short).to_f.ceil
    else
      short_to_dial=0
    end

    short_to_dial
  end

  def determine_pool_size(short_to_dial)
    stats = call_stats(10)

    #determine the how many new lines to dial based on short/long thresholds

    pool_size=0
    done_short=0

    callers_to_dial.each do |session|
      if session.attempt_in_progress.blank?
        # caller waiting idle
        pool_size = pool_size + stats[:dials_needed]
        #DIALER_LOGGER.info "empty to pool, session #{session.id} attempt_in_progress is blank"
      else
        attempt = CallAttempt.find(session.attempt_in_progress)
        if attempt.duration!=nil &&
            if attempt.duration < stats[:short_time] && done_short<short_to_dial
              if attempt.duration > stats[:short_new_call_time_threshold]
                #when stats[:short_new_call_caller_threshold] callers are on calls of length less than stats[:short_time]s, dial  stats[:dials_needed] lines at stats[:short_new_call_time_threshold]) seconds after the last call began.
                pool_size = pool_size + stats[:dials_needed]
                done_short+=1
                DIALER_LOGGER.info "short to pool, duration #{attempt.duration}, done_short=#{done_short}, short_to_dial=#{short_to_dial}"
              end
            else
              # if a call passes length 15s, dial stats[:dials_needed] lines at stats[:short_new_long_time_threshold]sinto the call.
              if attempt.duration > stats[:long_new_call_time_threshold]
                DIALER_LOGGER.info "LONG TO POOL, session #{session.id}, attempt.duration #{attempt.duration}, thresh #{stats[:long_new_call_time_threshold]}"
                pool_size = pool_size + stats[:dials_needed]
              end
            end
        end
      end
    end
    pool_size
  end

  def choose_voters_to_dial(num_voters)
    return [] if num_voters < 1
    priority_voters = all_voters.priority_voters.limit(num_voters)
    scheduled_voters = all_voters.scheduled.limit(num_voters)
    num_voters_to_call = (num_voters - (priority_voters.size + scheduled_voters.size))
    limit_voters = num_voters_to_call <= 0 ? 0 : num_voters_to_call
    voters =  priority_voters + scheduled_voters + all_voters.to_be_dialed.without(account.blocked_numbers.for_campaign(self).map(&:number)).limit(limit_voters)
    voters[0..num_voters-1]
  end

  def ratio_dial?
    predictive_type == "" || predictive_type.index("power_") == 0 || predictive_type.index("robo,") == 0
  end

  def dials_count
    (callers_to_dial.length - call_attempts_not_wrapped_up.length) * get_dial_ratio
  end

  def dial_predictive_voters
    if ratio_dial?
      num_to_call = (callers_to_dial.length - call_attempts_not_wrapped_up.length) * get_dial_ratio
    else
      num_to_call = dial_predictive_simulator
    end

    DIALER_LOGGER.info "#{self.name}: Callers logged in: #{callers.length}, Callers on call: #{callers_on_call.length}, Callers not on call:  #{callers_not_on_call}, Calls in progress: #{call_attempts_in_progress.length}"
    DIALER_LOGGER.info "num_to_call #{num_to_call}"
    if num_to_call > 0
      voter_ids = choose_voters_to_dial(num_to_call) #TODO check logic
      DIALER_LOGGER.info("voters to dial #{voter_ids}")
      ring_predictive_voters(voter_ids)
    end
  end

  def average(array)
  array.sum.to_f / array.size
  end

  def best_dials_simulated
    simulated_values.nil? ? 1 : simulated_values.best_dials.nil? ? 1 : simulated_values.best_dials.ceil
  end

  def best_conversation_simulated
    simulated_values.nil? ? 0 : simulated_values.best_conversation.nil? ? 0 : simulated_values.best_conversation
  end

  def longest_conversation_simulated
    simulated_values.nil? ? 0 : simulated_values.longest_conversation.nil? ? 0 : simulated_values.longest_conversation
  end

  def best_wrapup_simulated
    simulated_values.nil? ? 0 : simulated_values.best_wrapup_time.nil? ? 0 : simulated_values.best_wrapup_time
  end

  def num_to_call_predictive_simulate
    dials_made = call_attempts.between(10.minutes.ago, Time.now)
    calls_wrapping_up = dials_made.with_status(CallAttempt::Status::SUCCESS).not_wrapped_up
    active_call_attempts = dials_made.with_status(CallAttempt::Status::INPROGRESS)
    available_callers = caller_sessions.available.size + active_call_attempts.select { |call_attempt| ((call_attempt.duration_wrapped_up > best_conversation_simulated) && (call_attempt.duration_wrapped_up < longest_conversation_simulated))}.size + calls_wrapping_up.select{|wrapping_up_call| wrapping_up_call.time_to_wrapup > best_wrapup_simulated}.size
    ringing_lines = dials_made.with_status(CallAttempt::Status::RINGING).size
    dials_to_make = (best_dials_simulated * available_callers) - ringing_lines
    dials_to_make.to_i
  end

  def ring_predictive_voters(voter_ids)
    voter_ids.each do |voter|
      voter.dial_predictive
    end
  end

  def dial
    update_attribute(:calls_in_progress, true)
    dial_voters
    update_attribute(:calls_in_progress, false)
  end

  def start(user)
    return false if self.calls_in_progress? or (not self.account.activated?)
    return false if script.robo_recordings.size == 0
    Delayed::Job.enqueue BroadcastCampaignJob.new(self.id)
    UserMailer.new.notify_broadcast_start(self,user) if Rails.env == 'heroku'
    update_attribute(:calls_in_progress, true)
  end

  def stop
    Delayed::Job.all do |job|
        if job.name == "Broadcastcampaign-job-#{self.id}"
          job.delete
        end
    end
    update_attribute(:calls_in_progress, false)
  end

  def next_voter_in_dial_queue(current_voter_id = nil)
    voter = all_voters.priority_voters.first
    voter||= all_voters.scheduled.first
    voter||= all_voters.last_call_attempt_before_recycle_rate(recycle_rate).to_be_dialed.not_skipped.where("voters.id > #{current_voter_id}").first unless current_voter_id.blank?
    voter||= all_voters.last_call_attempt_before_recycle_rate(recycle_rate).to_be_dialed.not_skipped.first
    voter||= all_voters.last_call_attempt_before_recycle_rate(recycle_rate).to_be_dialed.where("voters.id != #{current_voter_id}").first unless current_voter_id.blank?
    voter||= all_voters.last_call_attempt_before_recycle_rate(recycle_rate).to_be_dialed.first
    unless voter.nil?
      begin
        voter.update_attributes(status: CallAttempt::Status::READY)
      rescue ActiveRecord::StaleObjectError
        next_voter_in_dial_queue(voter.id)
      end
    end
    voter
  end

  def voters_dialed
    call_attempts.count('voter_id', :distinct => true)
  end

  def voters_remaining
    all_voters.count - voters_dialed
  end


  def clear_calls
    all_voters.update_all(:result => nil, :status => 'not called')
  end

  # simulator dialer
  def dials_ramping?
    self.call_stats(10)[:attempts].length > 50 ? false : true
  end

  def dials_needed
    stats = call_stats(10)
    dials_made = stats[:attempts].length #number of dials made in the past 10 minutes
    dials_answered = stats[:answer] # number of dials answered in the past 10 minutes
    dials_needed = self.predictive_alpha * dials_answered / dials_made
  end

  def dialer_available_callers
    stats = call_stats(10)

    mean_conversation = stats[:avg_duration] #the mean length of a conversation in the last 10 minutes
    longest_conversation = stats[:biggest_long] #the length of the longest conversation in the last 10 minutes
    expected_conversation = (1 - predictive_beta) * mean_conversation + predictive_beta * longest_conversation
    available_callers = callers_available_for_call.length + callers_on_call_longer_than(expected_conversation).length - callers_on_call_longer_than(longest_conversation).length
  end

  def callers_on_call_longer_than(minute_threshold)
    results=[]
    callers_on_call.each do |caller|
      results << caller if caller.attempt_in_progress!=nil && CallAttempt.find(caller.attempt_in_progress).duration > minute_threshold
    end
    results
  end

  def abandon_rate_acceptable?
    answered_dials = call_attempts.between(10.minutes.ago, Time.now).with_status([CallAttempt::Status::SUCCESS, CallAttempt::Status::SCHEDULED]).size
    abandon_count = call_attempts.between(10.minutes.ago, Time.now).with_status(CallAttempt::Status::ABANDONED).size
    abandon_rate = abandon_count.to_f/answered_dials
    abandon_rate < acceptable_abandon_rate
  end

  def dial_predictive_simulator
    num_to_call = 0
    dials_made = call_attempts.between(10.minutes.ago, Time.now).size
    if dials_made == 0 || !abandon_rate_acceptable?
      num_to_call = callers_available_for_call.length - call_attempts.between(1.minute.ago, Time.now).with_status(CallAttempt::Status::RINGING).size
    else
      num_to_call = num_to_call_predictive_simulate
    end
    num_to_call
  end

  def answers_result(from_date, to_date)
    result = Hash.new
    unless script.nil?
      script.questions.each do |question|
        total_answers = question.answered_within(from_date, to_date, self.id).size
        result[question.text] = question.possible_responses.collect { |possible_response| possible_response.stats(from_date, to_date, total_answers, self.id) }
        result[question.text] << {answer: "[No response]", number: 0, percentage:  0} unless question.possible_responses.find_by_value("[No response]").present?
      end
    end

    result
  end

  def transfers(from_date, to_date)
    result = {}
    attempts = transfer_attempts.within(from_date, to_date, id)
    unless attempts.blank?
      result = TransferAttempt.aggregate(attempts)
    end
    result
  end

  def transfer_time(from_date, to_date)
    transfer_attempts.between(from_date, to_date + 1.day).sum('ceil(TIMESTAMPDIFF(SECOND ,connecttime,call_end)/60)').to_i
  end

  def voicemail_time(from_date, to_date)
    call_attempts.between(from_date, to_date + 1.day).with_status([CallAttempt::Status::VOICEMAIL]).sum('ceil(TIMESTAMPDIFF(SECOND ,connecttime,call_end)/60)').to_i
  end

  def abandoned_calls_time(from_date, to_date)
    call_attempts.between(from_date, to_date + 1.day).with_status([CallAttempt::Status::ABANDONED]).sum('ceil(TIMESTAMPDIFF(SECOND ,connecttime,call_end)/60)').to_i
  end

  def robo_answer_results(from_date, to_date)
    result = Hash.new
    unless script.nil?
      script.robo_recordings.each do |robo_recording|
        total_answers = robo_recording.answered_within(from_date, to_date, self.id).size
        result[robo_recording.name] = robo_recording.recording_responses.collect { |recording_response| recording_response.stats(from_date, to_date, total_answers, self.id) }
        result[robo_recording.name] << {answer: "[No response]", number: 0, percentage:  0} unless robo_recording.recording_responses.find_by_response("[No response]").present?
      end
    end
    result
  end



  private
  def dial_voters
    self.voter_lists.each do |voter_list|
      return unless self.calls_in_progress?
      voter_list.dial if voter_list.enabled
    end
  end
end
