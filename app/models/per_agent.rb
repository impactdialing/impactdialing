module PerAgent
	include SubscriptionProvider

	module ClassMethods    
  end

  module InstanceMethods		

  	def create_customer(token, email, plan_type, num_of_callers, amount)      
  		create_customer_plan(token, email, plan_type, num_of_callers)
  	end
	
	end

	def self.included(receiver)
    receiver.extend         ClassMethods
    receiver.send :include, InstanceMethods
  end

end