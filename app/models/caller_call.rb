class CallerCall < ActiveRecord::Base
  include Rails.application.routes.url_helpers
  include CallCenter
  include Event
  
  has_one :caller_session
  delegate :caller_reassigned_to_another_campaign?, :to => :caller_session
  delegate :time_period_exceeded?, :to => :caller_session
  delegate :campaign, :to => :caller_session
  
  
  
  def caller_disconnected?
    caller_session.endtime.nil?
  end
  
  
  # call_flow :state, :initial => :initial do    
  #   
  #     state :initial do
  #       event :start_conference, :to => :disconnected, :if => :caller_disconnected?
  #       event :start_conference, :to => :campaign_time_period_exceeded, :if => :time_period_exceeded?
  #       event :start_conference, :to => :connected
  #       event :start_conference, :to => :caller_reassigned, :if => :caller_reassigned_to_another_campaign?
  # 
  #     end 
  #     
  #     state :campaign_time_period_exceeded do        
  #       
  #       response do |xml_builder, the_call|          
  #         xml_builder.say I18n.t(:campaign_time_period_exceed, :start_time => campaign.start_time.hour <= 12 ? "#{campaign.start_time.hour} AM" : "#{campaign.start_time.hour-12} PM", :end_time => campaign.end_time.hour <= 12 ? "#{campaign.end_time.hour} AM" : "#{campaign.end_time.hour-12} PM")
  #         xml_builder.hangup
  #       end
  #       
  #     end
  #     
  #     state :connected do
  #       before(:always) { start_conference }
  #       
  #       response do |xml_builder, the_call|
  #         xml_builder.dial(:hangupOnStar => true, :action => caller_response_path) do
  #           xml_builder.conference(caller_session.session_key, :startConferenceOnEnter => false, :endConferenceOnExit => true, :beep => true, :waitUrl => hold_call_url(:host => Settings.host, :port => Settings.port, :version => HOLD_VERSION), :waitMethod => 'GET')        
  #         end                
  #       end
  #     end
  #     
  #     state :disconnected do
  #       
  #       response do |xml_builder, the_call|
  #         xml_builder.Hangup
  #       end
  #       
  #     end
  #     
  # end
end  