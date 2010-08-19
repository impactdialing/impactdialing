class Script < ActiveRecord::Base
  validates_presence_of :name, :on => :create, :message => "can't be blank"
  cattr_reader :per_page
  @@per_page = 25
end
