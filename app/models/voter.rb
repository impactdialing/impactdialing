class Voter < ActiveRecord::Base
  #  validates_uniqueness_of :Phone, :scope => [:campaign_id, :active] :message => " is already entered in this campaign"
  validates_presence_of :Phone, :on => :create, :message => "can't be blank"
  belongs_to :voter_list, :class_name => "VoterList", :foreign_key => "voter_list_id"
  has_many :families
  cattr_reader :per_page
  @@per_page = 25
 
  validate :unique_number
  
  def unique_number
    if !self.Phone.blank?
     if new_record?
#       errors.add("Phone is already entered in this campaign and") if Voter.find_by_Phone(self.Phone, :conditions=>"active=1 and campaign_id=#{self.campaign_id}")
     else
#       errors.add("Phone is already entered in this campaign and") if Voter.find_by_Phone(self.Phone, :conditions=>"active=1 and campaign_id=#{self.campaign_id} and id <> #{self.id}")
     end     
   end
  end
   
  def before_validation
    #clean up phone
     self.Phone = self.Phone.gsub(/[^0-9]/, "") unless self.Phone.blank?
  end
  
  
  def self.upload_headers
    ["Phone","ID","LastName","FirstName","MiddleName","Suffix","Email"]
  end
  
  def self.upload_fields
    ["Phone","CustomID","LastName","FirstName","MiddleName","Suffix","Email"]
  end
  
  def call_and_connect_to_session(session)
    require "hpricot"
    require "open-uri"
    campaign = session.campaign
    self.status='Call attempt in progress'
    self.save
    t = Twilio.new(TWILIO_ACCOUNT, TWILIO_AUTH)
    if !campaign.caller_id.blank? && campaign.caller_id_verified
      caller_num=campaign.caller_id
    else
      caller_num=APP_NUMBER
    end
    c = CallAttempt.new
    c.dialer_mode=campaign.predective_type
    c.voter_id=self.id
    c.campaign_id=campaign.id
    c.status="Call ready to dial"
    c.save

    if campaign.predective_type=="preview"
      a=t.call("POST", "Calls", {'Timeout'=>"20", 'Caller' => caller_num, 'Called' => self.Phone, 'Url'=>"#{APP_URL}/callin/voterFindSession?campaign=#{campaign.id}&voter=#{self.id}&attempt=#{c.id}&selected_session=#{session.id}"})
    elsif campaign.use_answering
      if campaign.use_recordings
        a=t.call("POST", "Calls", {'Timeout'=>campaign.answer_detection_timeout, 'Caller' => caller_num, 'Called' => self.Phone, 'Url'=>"#{APP_URL}/callin/voterFindSession?campaign=#{campaign.id}&voter=#{self.id}&attempt=#{c.id}&selected_session=#{session.id}", 'IfMachine'=>'Continue'})
      else
        a=t.call("POST", "Calls", {'Timeout'=>campaign.answer_detection_timeout, 'Caller' => caller_num, 'Called' => self.Phone, 'Url'=>"#{APP_URL}/callin/voterFindSession?campaign=#{campaign.id}&voter=#{self.id}&attempt=#{c.id}&selected_session=#{session.id}", 'IfMachine'=>'Hangup'})
      end
    else
      a=t.call("POST", "Calls", {'Timeout'=>"15", 'Caller' => caller_num, 'Called' => self.Phone, 'Url'=>"#{APP_URL}/callin/voterFindSession?campaign=#{campaign.id}&voter=#{self.id}&attempt=#{c.id}&selected_session=#{session.id}"})
    end
    @doc = Hpricot::XML(a)
    c.sid=(@doc/"Sid").inner_html
    c.status="Call in progress"
    c.save
    self.last_call_attempt_id=c.id
    self.last_call_attempt_time=Time.now
    self.save
  end
end
