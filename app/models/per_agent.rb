module PerAgent
	include SubscriptionProvider

	module ClassMethods
  end

  module InstanceMethods		

  	def create_customer(token, email, plan_type, num_of_callers, amount)      
  		create_customer_plan(token, email, plan_type, num_of_callers)
  	end

  	

    def same_plan_upgrade(new_plan)
      type == new_plan
    end

    def upgrading?(new_plan)      
      Subscription::Type::PAID_SUBSCRIPTIONS_ORDER[type] < Subscription::Type::PAID_SUBSCRIPTIONS_ORDER[new_plan] 
    end


  	def upgrade_subscription(token, email, plan_type, num_of_callers, amount)
  		if(same_plan_upgrade(plan_type) && (num_of_callers != number_of_callers))
  			update_callers(num_of_callers)
      elsif(same_plan_upgrade(plan_type) && (num_of_callers == number_of_callers))
        errors.add(:base, 'The subscription details submitted are identical to what already exists')        
  		else
        upgrading = upgrading?(plan_type)        
        change_subscription_type(plan_type)           
        return if self.errors.size > 0
  			account.subscription.upgrade(plan_type, num_of_callers, amount)        
  		  begin            
  			  update_subscription_plan({plan: Subscription.stripe_plan_id(plan_type), quantity: num_of_callers, prorate: upgrading})
          if upgrading
            invoice_customer
          else             
            recharge((account.subscription.number_of_callers*account.subscription.price_per_caller*100).to_i)         
          end                                                      
  			  update_info(retrieve_customer)
  		  rescue Exception => e  			 
  			 errors.add(:base, e.message)
  		  end  		
      end
  	end

  	
	end

	def self.included(receiver)
    receiver.extend         ClassMethods
    receiver.send :include, InstanceMethods
  end

end