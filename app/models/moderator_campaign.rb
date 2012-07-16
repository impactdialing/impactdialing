require 'redis/objects'
class ModeratorCampaign
  include Redis::Objects  
  value :id
  value :account_id
  value :moderator_id
  counter :callers_logged_in
  counter :on_call
  counter :wrapup
  counter :on_hold
  counter :live_lines
  counter :ringing_lines
  set :caller_status
  
  def initialize(campaign_id, num_callers_logged_in, num_on_call, num_wrapup, num_on_hold, num_live_lines, num_ringing_lines)
    @id = "monitor-" + campaign_id
    @campaign_id = campaign_id
    self.callers_logged_in.reset(num_callers_logged_in)
    self.on_call.reset(num_on_call)
    self.wrapup.reset(num_wrapup)
    self.on_hold.reset(num_on_hold)
    self.live_lines.reset(num_live_lines)
    self.ringing_lines.reset(num_ringing_lines)
  end
  
  
  
  def increment_callers_logged_in(num)
    ModeratorCampaign.increment_counter(:callers_logged_in, self.id, num)
  end
  
  def decrement_callers_logged_in(num)
    ModeratorCampaign.decrement_counter(:callers_logged_in, self.id, num)
  end

  def increment_on_call(num)
    ModeratorCampaign.increment_counter(:on_call, self.id, num)
  end
  
  def decrement_on_call(num)
    ModeratorCampaign.decrement_counter(:on_call, self.id, num)
  end

  def increment_wrapup(num)
    ModeratorCampaign.increment_counter(:wrapup, self.id, num)
  end
  
  def decrement_wrapup(num)
    ModeratorCampaign.decrement_counter(:wrapup, self.id, num)
  end
  
  def increment_on_hold(num)
    ModeratorCampaign.increment_counter(:on_hold, self.id, num)
  end
  
  def decrement_on_hold(num)
    ModeratorCampaign.decrement_counter(:on_hold, self.id, num)
  end
  
  def increment_live_lines(num)
    ModeratorCampaign.increment_counter(:live_lines, self.id, num)
  end
  
  def decrement_live_lines(num)
    ModeratorCampaign.decrement_counter(:live_lines, self.id, num)
  end
  
  def increment_ringing_lines(num)
    ModeratorCampaign.increment_counter(:ringing_lines, self.id, num)
  end
  
  def decrement_ringing_lines(num)
    ModeratorCampaign.decrement_counter(:ringing_lines, self.id, num)
  end
  
  
  
  
  
  
  
  
   
end