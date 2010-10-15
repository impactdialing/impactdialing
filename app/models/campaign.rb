class Campaign < ActiveRecord::Base
  require "fastercsv"
  validates_presence_of :name, :on => :create, :message => "can't be blank"
#  has_and_belongs_to_many :voter_lists
#  has_many :voter_lists
  has_many :voter_lists, :conditions => {:active => true}  
  has_and_belongs_to_many :callers
  belongs_to :script
  belongs_to :user
  belongs_to :recording
  cattr_reader :per_page
  @@per_page = 25
  
  def check_valid_caller_id_and_save
    check_valid_caller_id
    self.save
  end
  
  def check_valid_caller_id
    #verify caller_Id
    self.caller_id_verified=false
    if !self.caller_id.blank?
      #verify
      t = Twilio.new(TWILIO_ACCOUNT, TWILIO_AUTH)
      a=t.call("GET", "OutgoingCallerIds", {'PhoneNumber'=>self.caller_id})
      require 'rubygems'
      require 'hpricot'
      begin
        @doc = Hpricot::XML(a)
        code= (@doc/"Sid").inner_html
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
  
  def before_create
    uniq_pin=0
    while uniq_pin==0 do
      pin = rand.to_s[2..6]
      check = Campaign.find_by_group_id(pin)
      uniq_pin=pin if check.blank?
    end
    self.group_id = uniq_pin
  end
  
  def before_save
    #check_valid_caller_id if self.caller_id_changed?
    check_valid_caller_id
    
  end

  def recent_attempts(mins=10)
    attempts = CallAttempt.find_all_by_campaign_id(self.id, :conditions=>"call_start > DATE_SUB(now(),INTERVAL #{mins} MINUTE)", :order=>"id desc")
  end

  def end_all_calls(account,auth,appurl)
    in_progress = CallAttempt.find_all_by_campaign_id(self.id, :conditions=>"sid is not null and call_end is null and id > 45")
    in_progress.each do |attempt|
      t = Twilio.new(account,auth)
      a=t.call("POST", "Calls/#{attempt.sid}", {'CurrentUrl'=>"#{appurl}/callin/voterEndCall?attempt=#{attempt.id}"})
      attempt.call_end=Time.now
      attempt.save
    end
    in_progress
  end

  def calls_in_ending_window(period=10,predective_type="longest")
    #calls predicted to end soon
    stats = self.call_stats(period)
    if predective_type=="longest"
      window = stats[:biggest_long]
    else
      window = stats[:avg_long]
    end
    window = window - 10 if window > 10
#   RAILS_DEFAULT_LOGGER.debug("window: #{window}")
    ending = CallAttempt.all (:conditions=>"
    campaign_id=#{self.id}
    and status like'Connected to caller%'
    and timediff(now(),call_start) >SEC_TO_TIME(#{window})
    ")
    ending
  end
  
  def call_stats(mins=nil)
    stats={:attempts=>[], :abandon=>0, :answer=>0, :no_answer=>0, :total=>0, :answer_pct=>0, :avg_duration=>0, :abandon_pct=>0, :avg_hold_time=>0, :total_long=>0, :total_short=>0, :avg_long=>0, :biggest_long=>0, :avg_ring_time=>0, :avg_ring_time_devation=>0, :current_short=>0, :current_long=>0, :short_deviation=>0, :avg_short=>0}
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
		stats[:long_new_call_time_threshold] = ( stats[:avg_long] + (2*stats[:long_deviation]))- ( stats[:avg_ring_time] - (2*stats[:avg_ring_time_deviation]))
    
    # bimodal pacing algorithm:
    # when stats[:short_new_call_caller_threshold] callers are on calls of length less than stats[:short_time]s, dial  stats[:dials_needed] lines at stats[:short_new_call_time_threshold]) seconds after the last call began.
    # if a call passes length 15s, dial stats[:dials_needed] lines at stats[:short_new_long_time_threshold]sinto the call.        
        
    
		stats
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
#      RAILS_DEFAULT_LOGGER.debug("deviation error: #{values.inspect}")
      puts "deviation error: #{values.inspect}"
      return 0
    end
  end

  def voters(status=nil,include_call_retries=true,limit=300)
    return testVoters if self.name=="Load Test"
    return [] if  !self.user.paid
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
    
    if voters.length==0 && include_call_retries
      # no one left, so call everyone we missed over 10 minutes
      uncalled = Voter.find_all_by_campaign_id_and_active_and_call_back(self.id, 1, 1, :conditions=>"voter_list_id in (select id from voter_lists where campaign_id=#{self.id} and active=1 and enabled=1)")
      uncalled.each do |voter|
        if  voter.last_call_attempt_time!=nil && voter.last_call_attempt_time < Time.now - 10.minutes # && (voter.status==nil || voter.status==status )
          voters_returned << voter
        end
      end
      return voters #no randomize
    end
    
    voters_returned.sort_by{rand}
  end
  
  def voter_upload(upload,uid,seperator,voter_list_id)
    name = upload['datafile'].original_filename
    directory = "/tmp"
    path = File.join(directory, name)
    File.open(path, "wb") { |f| f.write(upload['datafile'].read) }
    
    all_headers=["Phone","VAN ID","LastName","FirstName","MiddleName","Suffix","Email"]
    headers_present={}
    num = 0
    pos=0
    result={:uploads=>[]}
    successCount=0
    failedCount=0

    FasterCSV.foreach(path, {:col_sep => seperator}) do |col|
      if num == 0
        # finding the col values
        col.each do |c|
          all_headers.each do |h|
            if h.downcase==c.downcase.strip
              headers_present[c.strip]=pos
            end
          end
          pos +=1
          
          # unless the column value is "R.No"(which is a roll no of student) find the subject using the abbreviation of that subject
          # unless c == "R.No"
          #   subj = Subject.first(:conditions => ["abbreviation = '#{c}'"])
          #   if subj.present?
          #     m.push(subj.id)
          #   end
          # end
        end
      else
        # process column
        if !headers_present.has_key?("Phone")
          return {:error=>"Could not process upload file.  Missing column header: Phone"}
        end
        
        #validation
        if col[headers_present["Phone"]]==nil || !phone_number_valid(col[headers_present["Phone"]])
          result[:uploads] << "Row " + (num+1).to_s + ": Invalid phone number"
          failedCount+=1
        elsif Voter.find_by_Phone_and_voter_list_id_and_active(phone_format(col[headers_present["Phone"]]),voter_list_id,true)
          result[:uploads] << "Row "  + (num+1).to_s + ": " + format_number_to_phone(col[headers_present["Phone"]]) + " already in this list"
          failedCount+=1
        else
          #valid row
          v = Voter.new
          v.campaign_id=self.id
          v.user_id=uid
          headers_present.keys.each do |h|
            #RAILS_DEFAULT_LOGGER.debug("#{h}: #{headers_present[h]}, #{col[headers_present[h]]}")
            thisHeader = h
            thisHeader="CustomID" if thisHeader=="VAN ID"
           # RAILS_DEFAULT_LOGGER.debug("thisHeader: #{thisHeader}, #{h}")
           if thisHeader=="Phone"
             val = phone_format(col[headers_present[h]])
           else
             val = col[headers_present[h]]
           end
           val="" if val==nil
            v.attributes={thisHeader=>val}
          end
          v.voter_list_id=voter_list_id
          v.save
          successCount+=1
        end
      end
      num += 1
    end
#    RAILS_DEFAULT_LOGGER.debug("present: #{headers_present.to_yaml}")
  result[:successCount]=successCount
  result[:failedCount]=failedCount
    return result
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
 
end
