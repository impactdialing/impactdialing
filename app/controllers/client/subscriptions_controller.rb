module Client
	class SubscriptionsController < ClientController
		before_filter :load_subscription

		def index			
		end

		def show			
		end

		def update			
			subscription = params[:subscription]			
			if @subscription.stripe_customer_id.nil?				
				@subscription.create_subscription(subscription[:stripeToken], account.users.first.email, subscription[:type], subscription[:number_of_callers], subscription[:amount])
			else
				@subscription.upgrade_subscription(subscription[:stripeToken], account.users.first.email, subscription[:type], subscription[:number_of_callers].to_i, subscription[:amount])
			end			
			if @subscription.errors.empty?
				flash_message(:notice, "Subscription Upgraded successfully")
				redirect_to client_subscriptions_path
			else
				flash_message(:error, @subscription.errors.full_messages.join)
				redirect_to client_subscription_path(subscription)
			end						
		end

		def update_callers
			@subscription.update_callers(params[:subscription][:num_callers].to_i)
			flash_message(:notice, "Callers have been updated successfully.")
			redirect_to client_subscriptions_path
		end

		def cancel
			@subscription.cancel
			flash_message(:notice, "Subscription has ben cancelled.")
			redirect_to client_subscriptions_path
		end

		def add_funds			
		end

		def add_to_balance			
			@subscription.recharge_subscription(params[:amount])
			flash_message(:notice, "The amount has been added to your balance.")
			redirect_to client_subscriptions_path
		end

		def configure_auto_recharge			
		end

		def auto_recharge			
			subscription = params[:subscription]
			@subscription.update_attributes(autorecharge_enabled: subscription[:autorecharge_enabled], 
				autorecharge_amount: subscription[:autorecharge_amount], autorecharge_trigger: subscription[:autorecharge_trigger])
			flash_message(:notice, "AutoRecharge options have been updated.")
			redirect_to client_subscriptions_path
		end

		def load_subscription
			@subscription = account.subscription
		end

	end
end	