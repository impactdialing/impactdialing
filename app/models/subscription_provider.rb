module SubscriptionProvider

	module ClassMethods
  end

  module InstanceMethods

		

		def create_customer_card(token, email)
			customer = Stripe::Customer.create(card: token, email: email)
		end

		def modify_customer_card(token)
			cu = Stripe::Customer.retrieve(stripe_customer_id)			
			cu.card = token
			cu.save			
			cu
		end

		def create_customer_charge(token, email, amount)		
			Stripe::Charge.create(amount: amount, currency: "usd", customer: stripe_customer_id)			
		end

		def retrieve_customer
			Stripe::Customer.retrieve(stripe_customer_id)
		end

		def update_subscription_plan(params)						
			retrieve_customer.update_subscription(params)						
		end

		def recharge
			customer = retrieve_customer
			Stripe::Charge.create(amount: amount_paid.to_i*100, currency: "usd", customer: customer.id)
		end

		def invoice_customer
			begin
				invoice = Stripe::Invoice.create(customer: stripe_customer_id)			
				invoice.pay
			rescue
			end
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