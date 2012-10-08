class MonitorCallerJob
  include Sidekiq::Worker

  
  def perform(campaign_id, caller_session_id, event, type)
    sessions = MonitorSession.sessions_last_hour(campaign_id)
    unless sessions.blank?
      sessions.each do |session|
        push_caller_info(session, campaign_id, caller_session_id, event) if type == "update"
        add_caller(session, campaign_id, caller_session_id, event) if type == "new"
        remove_caller(session, campaign_id, caller_session_id, event) if type == "delete"        
      end      
    end        
  end
  
  def push_caller_info(channel, campaign_id, caller_session_id, event)
    ::Pusher[channel].trigger!('update_caller_info', {campaign_id: campaign_id, caller_session: caller_session_id, event: event})
  end
  
  def add_caller(channel, campaign_id, caller_session_id, event)    
      caller = CallerSession.find(caller_session_id).caller
      caller.email = caller.identity_name
      caller_info = caller.info      
      caller_info.merge!({campaign_id: campaign_id, caller_session: caller_session_id, event: event})
      ::Pusher[channel].trigger!('caller_connected', caller_info)
  end
  
  def remove_caller(channel, campaign_id, caller_session_id, event)
    ::Pusher[channel].trigger!('caller_disconnected', {campaign_id: campaign_id, caller_session: caller_session_id, event: event})
  end
  
    
  
end