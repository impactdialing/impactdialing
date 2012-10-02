require 'resque-loner'

class CampaignOutOfNumbersJob
  include Resque::Plugins::UniqueJob
  @queue = :call_flow

   def self.perform(caller_session_id)
     caller_session = CallerSession.find(caller_session_id)
     caller_session.redirect_caller_out_of_numbers
   end
end