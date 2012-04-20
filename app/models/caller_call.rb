class CallerCall < ActiveRecord::Base
  include Rails.application.routes.url_helpers
  include CallCenter
  include Event
  
  has_one :caller_session
  
  
  # call_flow :state, :initial => :initial do    
  #   
  #     state :initial do
  #       event :incoming_call, :to => :connected
  #     end 
  #     
  #     state :connected do
  #       before(:always) { caller_conference_started}
  #       
  #       response do |xml_builder, the_call|
  #         if timeperiod_exceded
  #           Twilio::Verb.new do |v|
  #             v.say I18n.t(:campaign_time_period_exceed, :start_time => @campaign.start_time.hour <= 12 ? "#{@campaign.start_time.hour} AM" : "#{@campaign.start_time.hour-12} PM",
  #             :end_time => @campaign.end_time.hour <= 12 ? "#{@campaign.end_time.hour} AM" : "#{@campaign.end_time.hour-12} PM")
  #             v.hangup
  #           end.response
  #         end
  #         xml_builder.dial(:hangupOnStar => true, :action => caller_response_path) do
  #           xml_builder.conference(caller_session.session_key, :startConferenceOnEnter => false, :endConferenceOnExit => true, :beep => true, :waitUrl => hold_call_url(:host => Settings.host, :port => Settings.port, :version => HOLD_VERSION), :waitMethod => 'GET')        
  #       end        
  #       
  #     end
  #     
  #     
  # end
end  