module PerAgent
	include SubscriptionProvider

	module ClassMethods
  end

  module InstanceMethods		

  	def create_customer(token, email, plan_type, number_of_callers, amount)
  		create_customer_plan(token, email, plan_type, number_of_callers)
  	end

  	def create_subscription(token, email, plan_type, number_of_callers, amount)
  		begin
  			upgrade(plan_type, number_of_callers, amount)
      	customer = create_customer(token, email, plan_type, number_of_callers, amount)
      	update_info(customer)
      rescue Exception => e
      	puts e
      	errors.add(:base, e.message)
      end
  	end

  	def upgrade_subscription(token, email, plan_type, num_of_callers, amount)
  		if((plan_type == type) && (num_of_callers != number_of_callers))
  			update_callers(num_of_callers)
  		else
  			upgrade(plan_type, number_of_callers, amount)
  		end  		
  		begin
  			customer = retrieve_customer
  			update_subscription({plan: Subscription.stripe_plan_id(plan_type), quantity: number_of_callers, prorate: true})
  			invoice_customer
  			update_info(customer)
  		rescue Exception => e
  			puts e
  			errors.add(:base, e.message)
  		end  		
  	end

  	def update_callers(new_num_callers)    
    	if(new_num_callers < number_of_callers)
      	modified_subscription = update_subscription({quantity: new_num_callers, plan: stripe_plan_id, prorate: false})
      	remove_callers((number_of_callers-new_num_callers))
    	else
      	modified_subscription = update_subscription({quantity: new_num_callers, plan: stripe_plan_id, prorate: true})
      	invoice_customer
      	add_callers((new_num_callers-number_of_callers))
    	end
  	end

  	def add_callers(number_of_callers_to_add)
    	self.number_of_callers = number_of_callers + number_of_callers_to_add    
    	self.total_allowed_minutes +=  calculate_minute_on_add_callers(number_of_callers_to_add)    
    	self.save
  	end

  	def remove_callers(number_of_callers_to_remove)    
    	self.number_of_callers = number_of_callers - number_of_callers_to_remove    
    	self.save
  	end
	end

	def self.included(receiver)
    receiver.extend         ClassMethods
    receiver.send :include, InstanceMethods
  end

end