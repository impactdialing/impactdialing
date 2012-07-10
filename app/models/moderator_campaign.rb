require 'redis/objects'
class ModeratorCampaign
  include Redis::Objects  
  
  value :account_id
  value :moderator_id
  counter :callers_logged_in
  counter :on_call
  counter :wrapup
  counter :on_hold
  counter :live_lines
  counter :ringing_lines
  
  def initialize(account_id, moderator_id, campaign_id,callers_logged_in, on_call, wrapup, on_hold, live_lines, ringing_lines)
    @account_id = account_id
    @moderator_id = moderator_id
    @campaign_id = campaign_id
    @callers_logged_in = callers_logged_in
    @on_call = on_call
    @wrapup = wrapup
    @on_hold = on_hold
    @live_lines = live_lines
    @ringing_lines = ringing_lines
  end
  
  def increment_callers_logged_in(num)
    ModeratorCampaign.increment_counter(:callers_logged_in, self.id, num)
  end
  
  
  
  
   
end