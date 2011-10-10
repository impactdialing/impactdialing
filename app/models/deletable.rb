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
    receiver.scope :for_account, lambda {|account| { :conditions => ["account_id = ?", account.id] }}
  end
end

