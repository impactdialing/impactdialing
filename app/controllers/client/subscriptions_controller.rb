module Client
	class SubscriptionsController < ClientController
		before_filter :load_subscriptions

		def index			
		end

		def show			
		end

		def update			
			subscription = params[:subscription]									
			if Subscription.upgrade?(account.id, subscription[:type])
				new_subscription = upgrade_subscription(subscription) 
			elsif(Subscription.modify_callers?(account.id, subscription[:type], subscription[:number_of_callers]))
				new_subscription =  Subscription.modify_callers_to_existing_subscription(account.id, subscription[:number_of_callers].to_i)
			elsif(Subscription.downgrade?(account.id, subscription[:type]))
				new_subscription =  Subscription.downgrade_subscription(account.id, subscription[:stripeToken], account.users.first.email, subscription[:type], subscription[:number_of_callers], subscription[:amount])
			end			
			if new_subscription.errors.empty?
				flash_message(:notice, "Subscription Upgraded successfully")
				redirect_to client_subscriptions_path
			else
				flash_message(:error, new_subscription.errors.full_messages.join)
				redirect_to client_subscription_path(subscription)
			end						
		end

		def update_billing_info
			subscription = params[:subscription]									
			Subscription.create_customer(account.id, subscription[:stripeToken])
			flash_message(:notice, "Billing info has been updated successfully")
			redirect_to client_subscriptions_path
		end

		def update_billing
		end
		

		def cancel
			Subscription.cancel(account.id)			
			redirect_to client_subscriptions_path
		end

		def add_funds			
		end

		def add_to_balance					
			PerMinute.recharge_subscription(account.id, params[:amount])			
			flash_message(:notice, "The amount has been added to your balance.")
			redirect_to client_subscriptions_path
		end

		def configure_auto_recharge			
		end

		def auto_recharge		
			subscription = params[:subscription]
			PerMinute.configure_autorecharge(account.id, to_bool(subscription[:autorecharge_enabled]), subscription[:autorecharge_amount], subscription[:autorecharge_trigger])	
			
			
			flash_message(:notice, "AutoRecharge options have been updated.")
			redirect_to client_subscriptions_path
		end

		private

			def load_subscriptions
				@subscription = account.current_subscription
			end

			def upgrade_subscription(subscription)
				Subscription.upgrade_subscription(account.id, account.users.first.email, subscription[:type], subscription[:number_of_callers], subscription[:amount])			
			end



	end
end	