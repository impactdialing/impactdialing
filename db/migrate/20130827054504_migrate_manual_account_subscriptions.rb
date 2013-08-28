class MigrateManualAccountSubscriptions < ActiveRecord::Migration

  def up
  	Account.all.each do |account|
      if(account.subscription_name == "Manual")
      	Enterprise.create(account_id: account.id, subscription_start_date: DateTime.now, subscription_end_date: DateTime.now+10.years)        
      end
    end
  end

  def down
  end
end
