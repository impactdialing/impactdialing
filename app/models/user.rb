class User < ActiveRecord::Base
  validates_uniqueness_of :email, :message => " is already in use"
  validates_confirmation_of :password
  validates_format_of :email,
      :with => /^([^@\s]+)@((?:[-a-z0-9]+\.)+[a-z]{2,})$/i
  validates_presence_of :orgname, :on => :create, :message => "can't be blank"
  validates_presence_of :email, :on => :create, :message => "can't be blank"
  validates_presence_of :fname, :on => :create, :message => "can't be blank"
  validates_presence_of :lname, :on => :create, :message => "can't be blank"
  validates_presence_of :password, :on => :create, :message => "can't be blank"
  validates_length_of :password, :within => 5..50, :on => :create, :message => "must be 5 characters or greater"
  has_many :campaigns, :conditions => {:active => true}  
  has_many :recordings
  
  def admin
    if ["beans@beanserver.net", "michael@impactdialing.com","wolthuis@twilio.com"].index(self.email)
      true
    else
      false
    end
  end

  def show_voter_buttons
    if ["beans@beanserver.net", "wolthuis@twilio.com"].index(self.email)
      true
    else
      false
    end
  end

end
