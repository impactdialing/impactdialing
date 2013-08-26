module SubscriptionProvider

	module ClassMethods
  end

  module InstanceMethods

		def create_customer_plan(token, email, plan_type, num_of_callers)						
			Stripe::Customer.create(card: token, email: email, plan: Subscription.stripe_plan_id(plan_type), quantity: num_of_callers)
		end

		def create_customer_charge(token, email, amount)
			customer = Stripe::Customer.create(card: token, email: email)
			Stripe::Charge.create(amount: amount, currency: "usd", customer: customer.id)			
		end

		def retrieve_customer
			Stripe::Customer.retrieve(stripe_customer_id)
		end

		def update_subscription_plan(params)						
			retrieve_customer.update_subscription(params)						
		end

		def recharge()
			customer = retrieve_customer
			Stripe::Charge.create(amount: amount_paid.to_i*100, currency: "usd", customer: customer.id)
		end

		def invoice_customer
			invoice = Stripe::Invoice.create(customer: stripe_customer_id)
			invoice.pay
		end

		def cancel_subscription
			if per_agent?
				stripe_customer = Stripe::Customer.retrieve(stripe_customer_id)
		  	stripe_customer.cancel_subscription
		  end
		end
	end

	def self.included(receiver)
    receiver.extend         ClassMethods
    receiver.send :include, InstanceMethods
  end

	
end