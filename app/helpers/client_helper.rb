module ClientHelper
  def callerInCampaign(c)
    @campaign && @campaign.callers.include?(c)
  end

  def listInCampaign(c)
    @campaign && @campaign.voter_lists.include?(c)
  end

  def logged_in_as_client?
    session[:user] && @user
  end

  def logged_in_as_caller?
    session[:caller] && @caller
  end
  
  def recurly_subscription_url(plan_code, account_code, first_name, last_name, email)
      "https://impactdialing.recurly.com/subscribe/" + plan_code + "/" + account_code + "?first_name=" + URI.escape(first_name) + "&last_name=" + URI.escape(last_name) + "&email=" + URI.escape(email)
  end
    
end
