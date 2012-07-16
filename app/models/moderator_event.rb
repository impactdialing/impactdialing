module ModeratorEvent
  
  module ClassMethods
  end
  
  module InstanceMethods
    
    def pub
  end
  
  def self.included(receiver)
    receiver.extend         ClassMethods
    receiver.send :include, InstanceMethods
  end
  
  
end