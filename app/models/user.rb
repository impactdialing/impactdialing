class User < ActiveRecord::Base
  validates_uniqueness_of :email, :message => " is already in use"
  validates_format_of :email,
      :with => /^([^@\s]+)@((?:[-a-z0-9]+\.)+[a-z]{2,})$/i
  validates_presence_of :email, :on => :create, :message => "can't be blank"

  has_many :campaigns, :conditions => {:active => true}
  has_many :all_campaigns, :class_name => 'Campaign'
  has_many :recordings
  has_one :account
  has_many :scripts
  has_many :callers

  attr_accessor :new_password
  validates_presence_of :new_password, :on => :create, :message => "can't be blank"
  validates_length_of :new_password, :within => 5..50, :on => :create, :message => "must be 5 characters or greater"

  before_save :hash_new_password, :if => :password_changed?

  def password_changed?
    !!@new_password
  end

  def hash_new_password
    self.salt = ActiveSupport::SecureRandom.base64(8)
    self.hashed_password = Digest::SHA2.hexdigest(self.salt + @new_password)
  end

  def self.authenticate(email, password)
    if user = find_by_email(email)
      user if user.authenticate_with?(password)
    end
  end

  def authenticate_with?(password)
   self.hashed_password == Digest::SHA2.hexdigest(self.salt + password)
  end

  def create_reset_code
    update_attributes(:password_reset_code => Digest::SHA2.hexdigest(Time.new.to_s.split(//).sort_by{rand}.join))
  end

  def clear_reset_code
    update_attributes(:password_reset_code => nil)
  end

  def admin
    ["beans@beanserver.net", "michael@impactdialing.com","wolthuis@twilio.com","aa@beanserver.net"].index(self.email)
  end

  def admin?
    admin
  end

  def show_voter_buttons
    ["beans@beanserver.net", "wolthuis@twilio.com"].index(self.email)
  end

  def show_voter_buttons?
    show_voter_buttons
  end
  
  def send_welcome_email
    return false if self.domain!="impactdialing.com" && self.domain!="localhost"
    begin
      emailText="<p>Hi #{self.fname}! I think you're going love Impact Dialing, so I want to make you an offer: for the next two weeks, call for up to 1,000 minutes risk-free. If you aren't happy, we won’t charge you a thing. </p>
      <p>I could write pages about how we're different - unmatched scalability, incredible ease of use, fanatical service - but I think you'll enjoy using Impact Dialing more than reading about it. So head to admin.impactdialing.com and get calling before your 2 weeks are up!</p>
      <p>Also, I love hearing from our current and prospective clients. Whether it's a question, feature request, or just a note about how you're using Impact Dialing, let me know at twitter.com/impactdialing or facebook.com/impactdialing. Or, if you prefer, reply to this email. </p>
      <p>--<br/>
      Michael Kaiser-Nyman<br/>
      Founder & CEO, Impact Dialing<br/>
      (415) 347-5723</p>

      <p>P.S. Don't wait until it's too late - start your 2-week free trial now at admin.impactdialing.com.</p>"
      subject="Test drive Impact Dialing until " + (Date.today + 14).strftime("%B %d") 
      u = Uakari.new(MAILCHIMP_API_KEY)

      response = u.send_email({
          :track_opens => true, 
          :track_clicks => true, 
          :message => {
              :subject => subject, 
              :html => emailText, 
              :text => emailText, 
              :from_name => 'Impact Dialing', 
              :from_email => 'email@impactdialing.com', 
              :to_email => [self.email]
          }
      })
      rescue Exception => e
        logger.error(e.inspect)
    end
  end
end
