module Deletable

end


module Deletable
  module ClassMethods

  end

  module InstanceMethods

  end

  def self.included(receiver)
    receiver.extend         ClassMethods
    receiver.send :include, InstanceMethods

    receiver.named_scope :by_updated, lambda { { :order => ['updated_at desc'] } }
    receiver.named_scope :deleted, lambda { { :conditions => {:active => false} } }
    receiver.named_scope :active, lambda { { :conditions => {:active => true} } }
    receiver.named_scope :for_user, lambda {|user| { :conditions => ["user_id = ?", user.id] }}
  end
end

