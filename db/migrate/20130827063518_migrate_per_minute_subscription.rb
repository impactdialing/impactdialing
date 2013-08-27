class MigratePerMinuteSubscription < ActiveRecord::Migration
  def up
  	  Account.all.each do |account|
      if(account.subscription_name == "Per Minute")
      	PerMinute.create(account_id: account.id, subscription_start_date: DateTime.now, 
      	 subscription_end_date: DateTime.now+10.years, total_allowed_minutes: (account.current_balance/0.09), minutes_utlized: 0, 
      	 autorecharge_enabled: account.autorecharge_enabled, autorecharge_amount: account.autorecharge_amount, autorecharge_trigger: account.autorecharge_trigger)        
      end
    end
  end

  def down
  end
end
