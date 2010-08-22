class User < ActiveRecord::Base
  validates_uniqueness_of :email, :message => " is already in use"
  validates_presence_of :email, :on => :create, :message => "can't be blank"
  validates_presence_of :password, :on => :create, :message => "can't be blank"
  validates_length_of :password, :within => 5..20, :on => :create, :message => "must be 5 characters or greater"
  has_many :campaigns
end
