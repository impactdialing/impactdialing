require "twilio_lib"

class Campaign < ActiveRecord::Base
  include Deletable
  require "fastercsv"
  validates_presence_of :name, :on => :create, :message => "can't be blank"
  has_many :caller_sessions
  has_many :voter_lists, :conditions => {:active => true}
  has_many :all_voters, :class_name => 'Voter'
  has_many :call_attempts
  has_and_belongs_to_many :callers
  belongs_to :script
  belongs_to :account
  belongs_to :recording

  scope :robo, :conditions => {:robo => true }
  scope :manual, :conditions => {:robo => false }
  scope :for_account, lambda {|account| { :conditions => ["account_id = ?", account.id] }}
  scope :with_running_caller_sessions, {
      :select     => "distinct campaigns.*",
      :joins      => "inner join caller_sessions on (caller_sessions.campaign_id = campaigns.id)",
      :conditions => {"caller_sessions.on_call" => true}
  }
  scope :using_web_ui, :conditions => {:use_web_ui => true}

  before_create :create_uniq_pin

  cattr_reader :per_page
  @@per_page = 25

  before_save :before_save_campaign
  before_validation(:set_untitled_name, :on => :create)

  def set_untitled_name
    self.name = "Untitled #{account.campaigns.count + 1}" if self.name.blank?
  end

  # TODO: remove
  def check_valid_caller_id_and_save
    check_valid_caller_id
    self.save
  end

  # TODO: remove
  def check_valid_caller_id
    #verify caller_Id
    self.caller_id_verified=false
    if !self.caller_id.blank?
      #verify
      t = TwilioLib.new(TWILIO_ACCOUNT, TWILIO_AUTH)
      a=t.call("GET", "OutgoingCallerIds", {'PhoneNumber'=>self.caller_id})
      require 'rubygems'
      require 'hpricot'
      begin
        @doc = Hpricot::XML(a)
        code = (@doc/"Sid").inner_html
        if code.blank?
          self.caller_id_verified=false
        else
          self.caller_id_verified=true
        end
      rescue
      end
    end
    true
  end

  def create_uniq_pin
    uniq_pin=0
    while uniq_pin==0 do
      pin = rand.to_s[2..6]
      check = Campaign.find_by_group_id(pin)
      uniq_pin=pin if check.blank?
    end
    self.group_id = uniq_pin
  end

  def before_save_campaign
    self.check_valid_caller!
    true
  end

  def caller_id_object
    CallerIdObject.new(caller_id, 'FriendlyName' => "Campaign #{self.id}")
  end

  def check_valid_caller!
    self.caller_id_verified = self.caller_id_object.validate
  end

  def recent_attempts(mins=10)
    attempts = CallAttempt.find_all_by_campaign_id(self.id, :conditions=>"call_start > DATE_SUB(now(),INTERVAL #{mins} MINUTE)", :order=>"id desc")
  end

  def end_all_calls(account,auth,appurl)
    in_progress = CallAttempt.find_all_by_campaign_id(self.id, :conditions=>"sid is not null and call_end is null and id > 45")
    in_progress.each do |attempt|
      t = TwilioLib.new(account,auth)
      a=t.call("POST", "Calls/#{attempt.sid}", {'CurrentUrl'=>"#{appurl}/callin/voterEndCall?attempt=#{attempt.id}"})
      attempt.call_end=Time.now
      attempt.save
    end
    in_progress
  end

  def end_all_callers(account,auth,appurl)
    in_progress = CallerSession.find_all_by_campaign_id(self.id, :conditions=>"on_call=1")
    in_progress.each do |caller|
      t = TwilioLib.new(account,auth)
      a=t.call("POST", "Calls/#{caller.sid}", {'CurrentUrl'=>"#{appurl}/callin/callerEndCall?session=#{caller.id}"})
      if a.index("RestException")
        caller.on_call=false
        caller.save
      end
    end
    in_progress
  end

  def calls_in_ending_window(period=10,predictive_type="longest")
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
    @stats ||= {:attempts=>[], :abandon=>0, :answer=>0, :no_answer=>0, :total=>0, :answer_pct=>0, :avg_duration=>0, :abandon_pct=>0, :avg_hold_time=>0, :total_long=>0, :total_short=>0, :avg_long=>0, :biggest_long=>0, :avg_ring_time=>0, :avg_ring_time_devation=>0, :current_short=>0, :current_long=>0, :short_deviation=>0, :avg_short=>0}.tap do |stats|
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
        attempts = CallAttempt.find_all_by_campaign_id(self.id, :conditions=>"call_start > DATE_SUB(now(),INTERVAL #{mins} MINUTE) or call_end > DATE_SUB(now(),INTERVAL #{mins} MINUTE)", :order=>"id desc")
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
            stats[:total_short]  = stats[:total_short]+1
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
      stats[:abandon_pct] = stats[:abandon].to_f / (stats[:answer].to_f + stats[:abandon].to_f ) if stats[:answer] > 0
      stats[:avg_duration] = totduration / stats[:answer].to_f  if stats[:answer] > 0
      stats[:avg_hold_time] = tothold/ totholddata  if totholddata> 0
      stats[:avg_long] = totlongduration / stats[:total_long] if stats[:total_long] > 0
      stats[:avg_short] = totshortduration / stats[:total_short] if stats[:total_short] > 0
      stats[:avg_ring_time] = totringtime/totringattempts if totringattempts >0
      stats[:avg_ring_time_deviation] = self.std_deviation(ringattempts)
      stats[:long_deviation] = self.std_deviation(longattempts)
      stats[:short_deviation] = self.std_deviation(shortattempts)
      stats[:answer_plus_abandon_ct] = (stats[:abandon].to_f + stats[:answer].to_f) / stats[:total].to_f if stats[:total] > 0


      #new algo stuff
      if stats[:answer_plus_abandon_ct] ==nil
        stats[:dials_needed]  = 2
      else
        dials = 1 / stats[:answer_plus_abandon_ct]
        dials = 2 if dials.infinite?
        dials = dials.to_f.round
        dials = self.max_calls_per_caller if dials > self.max_calls_per_caller
        dials = 2 if attempts.length < 50
        #      dials=1
        stats[:dials_needed]  = dials
      end
      stats[:avg_ring_time_adjusted] =  stats[:avg_ring_time] - (2*stats[:avg_ring_time_deviation])
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
      stats[:short_new_call_time_threshold] = ( stats[:avg_short] + (2*stats[:short_deviation]) ) - ( stats[:avg_ring_time] - (2*stats[:avg_ring_time_deviation]) )
      if self.predictive_type=="algorithm1"
        stats[:long_new_call_time_threshold] = ( stats[:avg_long] + (2*stats[:long_deviation]))- ( stats[:avg_ring_time] - (2*stats[:avg_ring_time_deviation]))
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

  def testVoters
    v = Voter.find_by_CustomID("Load Test")
    voters=[]
    (1..200).each do |n|
      voters<<v
    end
    voters
  end

  def voters_count(status=nil,include_call_retries=true)
    active_lists = VoterList.find_all_by_campaign_id_and_active_and_enabled(self.id, 1, 1)
    return [] if active_lists.length==0
    active_list_ids = active_lists.collect {|x| x.id}
    #voters = Voter.find_all_by_voter_list_id(active_list_ids)

    Voter.find_all_by_active(1, :select=>"id", :conditions=>"voter_list_id in (#{active_list_ids.join(",")})  and (status='#{status}' OR (call_back=1 and last_call_attempt_time < (Now() - INTERVAL 180 MINUTE)) )")
#    Voter.find_by_sql("select count(*) as count from voters where voter_list_id in (#{active_list_ids.join(",")})  and (status='#{status}' OR (call_back=1 and last_call_attempt_time < (Now() - INTERVAL 180 MINUTE)) )")

  end


  def std_deviation(values)
    return 0 if values==nil || values.size==0
    begin
      count = values.size
      mean = values.inject(:+) / count.to_f
      stddev = Math.sqrt( values.inject(0) { |sum, e| sum + (e - mean) ** 2 } / count.to_f )
    rescue
#      Rails.logger.debug("deviation error: #{values.inspect}")
      puts "deviation error: #{values.inspect}"
      return 0
    end
  end

  def voters(status=nil,include_call_retries=true,limit=300)
    #return testVoters if self.name=="Load Test"
    return [] if  !self.account.paid
    return [] if self.caller_id.blank? || !self.caller_id_verified
    voters_returned=[]
    voter_ids=[]

    active_lists = VoterList.find_all_by_campaign_id_and_active_and_enabled(self.id, 1, 1)
    return [] if active_lists.length==0
    active_list_ids = active_lists.collect {|x| x.id}
    #voters = Voter.find_all_by_voter_list_id(active_list_ids)

    voters = Voter.find_all_by_campaign_id_and_active(self.id, 1, :conditions=>"voter_list_id in (#{active_list_ids.join(",")})", :limit=>limit, :order=>"rand()")
    voters.each do |voter|
      if !voter_ids.index(voter.id) && (voter.status==nil || voter.status==status )
        voters_returned << voter
        voter_ids  << voter.id
#      elsif !voter_ids.index(voter.id) && include_call_retries && voter.call_back? && voter.last_call_attempt_time!=nil && voter.last_call_attempt_time < (Time.now - 3.hours)
      elsif !voter_ids.index(voter.id) && include_call_retries && voter.call_back? && voter.last_call_attempt_time!=nil && voter.last_call_attempt_time < (Time.now - 180.minutes)
        voters_returned << voter
        voter_ids  << voter.id
      end
    end

    if voters_returned.length==0 && include_call_retries
      # no one left, so call everyone we missed over 10 minutes
      uncalled = Voter.find_all_by_campaign_id_and_active_and_call_back(self.id, 1, 1, :conditions=>"voter_list_id in (select id from voter_lists where campaign_id=#{self.id} and active=1 and enabled=1)")
      uncalled.each do |voter|
        if voter.last_call_attempt_time!=nil && voter.last_call_attempt_time < Time.now - 10.minutes # && (voter.status==nil || voter.status==status )
          voters_returned << voter
        end
      end
      return voters_returned.sort_by{rand}
    end

    voters_returned.sort_by{rand}
  end

  def phone_format(str)
    return "" if str.blank?
    str.gsub(/[^0-9]/, "")
  end

  def phone_number_valid(str)
    if (str.blank?)
      return false
    end
    str.scan(/[0-9]/).size > 9
  end

  def format_number_to_phone(number, options = {})
    number       = number.to_s.strip unless number.nil?
    options      = options.symbolize_keys
    area_code    = options[:area_code] || nil
    delimiter    = options[:delimiter] || "-"
    extension    = options[:extension].to_s.strip || nil
    country_code = options[:country_code] || nil

    begin
      str = ""
      str << "+#{country_code}#{delimiter}" unless country_code.blank?
      str << if area_code
               number.gsub!(/([0-9]{1,3})([0-9]{3})([0-9]{4}$)/,"(\\1) \\2#{delimiter}\\3")
      else
        number.gsub!(/([0-9]{0,3})([0-9]{3})([0-9]{4})$/,"\\1#{delimiter}\\2#{delimiter}\\3")
        number.starts_with?('-') ? number.slice!(1..-1) : number
      end
      str << " x #{extension}" unless extension.blank?
      str
    rescue
      number
    end
  end

  def dialing?
    (predictive_type == 'preview' || calls_in_progress?).tap do
      DIALER_LOGGER.info "SKIP #{self.name} dials in progress #{self.calls_in_progress?} #{self.predictive_type}"
    end
  end

  def predictive_dial
    return if dialing?
    DIALER_LOGGER.info "Working on campaign #{self.name}"
    update_attribute(:calls_in_progress, true)
    dial_predictive_voters
    update_attribute(:calls_in_progress, false)
  end

  def callers
    CallerSession.find_all_by_campaign_id_and_on_call(self.id, 1)
  end

  def callers_on_call
    CallerSession.find_all_by_campaign_id_and_on_call_and_available_for_call(self.id, 1, 0)
  end

  def call_attempts_in_progress
    CallAttempt.find_all_by_campaign_id(self.id, :conditions=>"call_end is NULL")
  end

  def callers_not_on_call
    callers.length - callers_on_call.length
  end

  def get_dial_ratio



    if self.predictive_type.index("power_")!=nil
      ratio_dial = self.predictive_type[6, 1].to_i
      DIALER_LOGGER.info "ratio_dial: #{ratio_dial}, #{callers.length}, #{campaign.predictive_type.index("power_")}"
    end

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

    callers.each do |session|
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
    scheduled_voter_ids = self.all_voters.scheduled.limit(num_voters)
    (scheduled_voter_ids + self.voters('not called')).reject(&:blocked?).uniq[0..num_voters]
  end

  def ratio_dial?
    predictive_type=="" || predictive_type.index("power_")==0 || predictive_type.index("robo,")==0
  end

  def dial_predictive_voters
    if ratio_dial?
      num_to_call= (callers.length - call_attempts_in_progress.length) * get_dial_ratio
    else
      short_to_dial=determine_short_to_dial(stats)
      max_calls=determine_pool_size(short_to_dial)
      num_to_call=max_calls-call_attempts_in_progress.length
    end

    DIALER_LOGGER.info "#{self.name}: Callers logged in: #{callers.length}, Callers on call: #{callers_on_call.length}, Callers not on call:  #{callers_not_on_call}, Calls in progress: #{call_attempts_in_progress.length}, Answer pct: #{(stats[:answer_pct] * 100).to_i}"
    DIALER_LOGGER.info "#{new_calls} newcalls #{max_calls} maxcalls"

    voter_ids=choose_voters_to_dial(num_to_call) #TODO check logic
    DIALER_LOGGER.info("voters to dial #{voter_ids}")
    #ring_predictive_voters(voter_ids)
  end

  def ring_predictive_voters(voter_ids)
    voter_ids.each do |voter|
      voter.dial_predictive
    end
  end

  def dial
    update_attribute(:calls_in_progress, true)
    dial_voters()
    update_attribute(:calls_in_progress, false)
  end

  def start
    return false if self.calls_in_progress? or (not self.account.paid)
    return false if script.robo_recordings.size == 0
    daemon = "#{Rails.root.join('script', "dialer_control.rb start -- #{self.id}")}"
    logger.info "[dialer] Account id:#{self.account.id} started campaign id:#{self.id} name:#{self.name}"
    update_attribute(:calls_in_progress, true)
    system(daemon)
  end

  def stop
    update_attribute(:calls_in_progress, false)
  end

  def voters_dialed
    self.call_attempts.count('voter_id', :distinct => true)
  end

  def voters_remaining
    self.all_voters.count - voters_dialed
  end

  module Type
    PREVIEW = "preview"
    PREDICTIVE = "predictive"
  end

  def clear_calls
    all_voters.update_all(:result => nil, :status => 'not called')
  end

  private
  def dial_voters
    self.voter_lists.each do |voter_list|
      return unless self.calls_in_progress?
      voter_list.dial if voter_list.enabled
    end
  end
end
