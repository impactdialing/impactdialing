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
  
  
   
end