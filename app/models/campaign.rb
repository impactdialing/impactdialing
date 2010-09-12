class Campaign < ActiveRecord::Base
  require "fastercsv"
  validates_presence_of :name, :on => :create, :message => "can't be blank"
#  has_and_belongs_to_many :voter_lists
#  has_many :voter_lists
  has_many :voter_lists, :conditions => {:active => true}  
  has_and_belongs_to_many :callers
  belongs_to :script
  belongs_to :user
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
    stats={:attempts=>[], :abandon=>0, :answer=>0, :no_answer=>0, :total=>0, :answer_pct=>0, :avg_duration=>0, :abandon_pct=>0, :avg_hold_time=>0, :total_long=>0, :total_short=>0, :avg_long=>0, :biggest_long=>0}
    totduration=0
    tothold=0
    totholddata=0
    totlongduration=0

    if mins.blank?
      attempts = CallAttempt.find_all_by_campaign_id(self.id, :order=>"id desc")
    else
      attempts = CallAttempt.find_all_by_campaign_id(self.id, :conditions=>"call_start > DATE_SUB(now(),INTERVAL #{mins} MINUTE) or call_end > DATE_SUB(now(),INTERVAL #{mins} MINUTE)", :order=>"id desc")
    end

    stats[:attempts]=attempts

    attempts.each do |attempt|

      if attempt.status=="No answer"
        stats[:no_answer] = stats[:no_answer]+1
      elsif attempt.status=="Call abandoned"
        stats[:abandon] = stats[:abandon]+1
      else
        stats[:answer] = stats[:answer]+1
      end

      stats[:total] = stats[:total]+1

      if attempt.duration!=nil && attempt.duration>0
        totduration = totduration + attempt.duration 
        if attempt.duration <= 15
          stats[:total_short]  = stats[:total_short]+1
        else
          stats[:total_long] = stats[:total_long]+1
          stats[:biggest_long] = attempt.duration if attempt.duration > stats[:biggest_long]
          totlongduration = totlongduration + attempt.duration
        end
      end

      if !attempt.caller_hold_time.blank?
        tothold = tothold + attempt.caller_hold_time 
        totholddata+=1
      end
    end
#    avg_hold_time
    stats[:answer_pct] = stats[:answer].to_f/ stats[:total].to_f if stats[:total] > 0
    stats[:abandon_pct] = stats[:abandon].to_f / stats[:answer].to_f if stats[:answer] > 0
    stats[:avg_duration] = totduration / stats[:answer].to_f  if stats[:answer] > 0
    stats[:avg_hold_time] = tothold/ totholddata  if totholddata> 0
    stats[:avg_long] = totlongduration / stats[:total_long] if stats[:total_long] > 0
    stats
  end
  
  def voters_called
    voters=[]
#    self.voter_lists.each do |list|
    votersq = Voter.find_all_by_campaign_id (self.id)
    votersq.each do |voter|
      if voter.status!='not called'
        voters << voter
      end
    end
    # VoterList.find_all_by_campaign_id_and_active_and_enabled(self.id, 1, 1).each do |list|
    #   list.voters.each do |voter|
    #     if voter.status!='not called'
    #       voters << voter
    #     end
    #   end
    # end
    voters
  end

  def testVoters
    v = Voter.find_by_CustomID("Load Test")
    voters=[]
    (1..200).each do |n|
      voters<<v
    end
    voters
  end

  def voters(status=nil,include_call_retries=true)
    return testVoters if self.user.id==1
    return [] if  !self.user.paid
    return [] if self.caller_id.blank? || !self.caller_id_verified
    voters_returned=[]
    voter_ids=[]

    active_lists = VoterList.find_all_by_campaign_id_and_active_and_enabled(self.id, 1, 1)
    return [] if active_lists.length==0
    active_list_ids = active_lists.collect {|x| x.id}
    #voters = Voter.find_all_by_voter_list_id(active_list_ids)

    voters = Voter.find_all_by_campaign_id_and_active(self.id, 1, :conditions=>"voter_list_id in (#{active_list_ids.join(",")})")
    
    voters.each do |voter|
      if !voter_ids.index(voter.id) && (status==nil || voter.status==status )
        voters_returned << voter
        voter_ids  << voter.id
      elsif !voter_ids.index(voter.id) && include_call_retries && voter.call_back? && voter.last_call_attempt_time!=nil && voter.last_call_attempt_time < (Time.now - 3.hours)
        voters_returned << voter
        voter_ids  << voter.id
      end
    end
    
    if voters.length==0 && include_call_retries
      # no one left, so call everyone we missed over 10 minutes
      uncalled = Voter.find_all_by_campaign_id_and_active_and_call_back(self.id, 1, 1, :conditions=>"voter_list_id in (select id from voter_lists where campaign_id=#{self.id} and active=1 and enabled=1)")
      uncalled.each do |voter|
        if  voter.last_call_attempt_time!=nil && voter.last_call_attempt_time < Time.now - 10.minutes
          voters_returned << voter
        end
      end
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
