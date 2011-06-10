class Voter < ActiveRecord::Base
  belongs_to :voter_list
  has_many :families

  validates_presence_of :Phone
  validates_length_of :Phone, :minimum => 10
  validates_uniqueness_of :Phone, :scope => :voter_list_id

  named_scope :existing_phone, lambda { |phone_number, voter_list_id|
    {:conditions => ['Phone = ? and voter_list_id = ?', phone_number, voter_list_id]}
  }
  cattr_reader :per_page
  @@per_page = 25

  def self.sanitize_phone(phonenumber)
    phonenumber.gsub(/[^0-9]/, "") unless phonenumber.blank?
  end

  def before_validation
    self.Phone = Voter.sanitize_phone(self.Phone)
  end

  def self.upload_headers
    ["Phone", "ID", "LastName", "FirstName", "MiddleName", "Suffix", "Email"]
  end

  def self.upload_fields
    ["Phone", "CustomID", "LastName", "FirstName", "MiddleName", "Suffix", "Email"]
  end

  def call_and_connect_to_session(session)
    require "hpricot"
    require "open-uri"
    campaign   = session.campaign
    self.status='Call attempt in progress'
    self.save
    t = Twilio.new(TWILIO_ACCOUNT, TWILIO_AUTH)
    if !campaign.caller_id.blank? && campaign.caller_id_verified
      caller_num=campaign.caller_id
    else
      caller_num=APP_NUMBER
    end
    c            = CallAttempt.new
    c.dialer_mode=campaign.predective_type
    c.voter_id   =self.id
    c.campaign_id=campaign.id
    c.status     ="Call ready to dial"
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
    @doc    = Hpricot::XML(a)
    c.sid   =(@doc/"Sid").inner_html
    c.status="Call in progress"
    c.save
    self.last_call_attempt_id  =c.id
    self.last_call_attempt_time=Time.now
    self.save
  end

end
