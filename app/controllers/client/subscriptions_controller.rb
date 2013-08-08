module Client

	class SubscriptionsController < ClientController

		def index
		end

		def update
			subscription = account.subscription
			plan_type = params[:subscription][:type]
			number_of_callers = params[:subscription][:number_of_callers]
			subscription.upgrade_to_paid_subscription(params[:subscription][:stripeToken], account.users.first.email, plan_type, number_of_callers)				
		end

		def update_callers
			account.subscription.update_callers(params[:subscription][:num_callers].to_i)
		end

		def cancel
			account.subscription.cancel			
		end

	end
end	