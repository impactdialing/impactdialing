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
  
  def logged_in_as_phones_only_caller?
    session[:phones_only_caller] && @caller
  end
  
  
end
