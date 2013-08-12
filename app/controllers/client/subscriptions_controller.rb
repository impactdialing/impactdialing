module Client
	class SubscriptionsController < ClientController

		def index
			@subscription = account.subscription
		end

		def show
			@subscription = account.subscription
		end


		def update
			subscription = account.subscription
			plan_type = params[:subscription][:type]
			number_of_callers = params[:subscription][:number_of_callers]
			subscription.upgrade_subscription(params[:subscription][:stripeToken], account.users.first.email, plan_type, number_of_callers)
			if subscription.errors.empty?
				flash_message(:notice, "Subscription Upgraded successfully")
				redirect_to client_subscriptions_path
			else
				flash_message(:error, subscription.errors.full_messages.join)
				redirect_to client_subscription_path(subscription)
			end						
		end

		def update_callers
			account.subscription.update_callers(params[:subscription][:num_callers].to_i)
			flash_message(:notice, "Callers have been updated successfully.")
			redirect_to client_subscriptions_path
		end

		def cancel
			account.subscription.cancel
			flash_message(:notice, "Subscription has ben cancelled.")
			redirect_to client_subscriptions_path
		end

	end
end	