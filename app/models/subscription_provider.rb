module SubscriptionProvider

	module ClassMethods
  end

  module InstanceMethods

		def create_customer(token, email, plan_type, number_of_callers)
			Stripe::Customer.create(card: token, email: email, plan: Subscription.stripe_plan_id(plan_type), quantity: number_of_callers)
		end

		def retrieve_customer
			Stripe::Customer.retrieve(stripe_customer_id)
		end

		def update_subscription(params)
			stripe_customer = retrieve_customer
			stripe_customer.update_subscription(params)
		end

		def invoice_customer
			invoice = Stripe::Invoice.create(customer: stripe_customer_id)
			invoice.pay
		end

		def cancel
			stripe_customer = Stripe::Customer.retrieve(stripe_customer_id)
	    cu.cancel_subscription
		end
	end

	def self.included(receiver)
    receiver.extend         ClassMethods
    receiver.send :include, InstanceMethods
  end

	
end