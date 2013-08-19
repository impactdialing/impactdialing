module PerAgent
	include SubscriptionProvider

	module ClassMethods
  end

  module InstanceMethods		

  	def create_customer(token, email, plan_type, number_of_callers, amount)
  		create_customer_plan(token, email, plan_type, number_of_callers)
  	end


  	def upgrade(new_plan, num_of_callers=1, amount=0)        		
    	account.subscription.number_of_callers = num_of_callers      
      account.subscription.subscribe
    	account.subscription.save          
  	end

  	def upgrade_subscription(token, email, plan_type, num_of_callers, amount)
  		if((plan_type == type) && (num_of_callers != number_of_callers))
  			update_callers(num_of_callers)
      elsif((plan_type == type) && (num_of_callers == number_of_callers))
        errors.add(:base, 'The subscription details submitted are identical to what already exists')
  		else
        change_subscription_type(plan_type)      
  			account.subscription.upgrade(plan_type, num_of_callers, amount)        
  		  begin                   
  			 customer = retrieve_customer         
  			 update_subscription_plan({plan: Subscription.stripe_plan_id(plan_type), quantity: num_of_callers, prorate: true})         
  			 invoice_customer         
  			 update_info(customer)
  		  rescue Exception => e
  			 puts e
  			 errors.add(:base, e.message)
  		  end  		
      end
  	end

  	def update_callers(new_num_callers)          
    	if(new_num_callers < number_of_callers)
        begin          
      	 modified_subscription = update_subscription_plan({quantity: new_num_callers, plan: stripe_plan_id, prorate: false})
        rescue Stripe::InvalidRequestError => e
          errors.add(:base, 'Please submit a valid number of callers')
          return
        end
      	remove_callers((number_of_callers-new_num_callers))
    	else
        begin
      	 modified_subscription = update_subscription_plan({quantity: new_num_callers, plan: stripe_plan_id, prorate: true})
      	 invoice_customer
        rescue Stripe::InvalidRequestError => e
          errors.add(:base, 'Please submit a valid number of callers')
          return
        end
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