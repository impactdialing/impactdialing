class MigratePerCallerSubscriptions < ActiveRecord::Migration
  def up
  	Account.all.each do |account|
      if(account.subscription_name == "Per Caller")
      	Trial.create(account_id: account.id, subscription_start_date: DateTime.now, subscription_end_date: DateTime.now+30.days, total_allowed_minutes: 0 , minutes_utlized: 0, number_of_callers: 1)        
      end      
    end
  end

  def down
  end
end
