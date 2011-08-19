module Deletable
  module ClassMethods
  end

  module InstanceMethods
    def restore
      self.active = true
    end

    def delete
      self.active = false
    end
  end

  def self.included(receiver)
    receiver.extend         ClassMethods
    receiver.send :include, InstanceMethods

    receiver.scope :by_updated, lambda { { :order => ['updated_at desc'] } }
    receiver.scope :deleted, lambda { { :conditions => {:active => false} } }
    receiver.scope :active, lambda { { :conditions => {:active => true} } }
    receiver.scope :for_user, lambda {|user| { :conditions => ["user_id = ?", user.id] }}
  end
end

