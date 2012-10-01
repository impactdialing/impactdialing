require Rails.root.join("lib/twilio_lib")
class TransferAttempt < ActiveRecord::Base
  belongs_to :transfer
  belongs_to :caller_session
  belongs_to :call_attempt
  belongs_to :campaign
  include Rails.application.routes.url_helpers
  scope :within, lambda { |from, to, campaign_id| where(:created_at => from..to).where(campaign_id: campaign_id)}
  scope :between, lambda { |from_date, to_date| {:conditions => {:created_at => from_date..to_date}} }

  
  
  
  def conference
    Twilio::TwiML::Response.new do |r|
      r.Dial :hangupOnStar => 'false', :action => disconnect_transfer_path(self, :host => Settings.twilio_callback_host), :record=>caller_session.campaign.account.record_calls do |d|
        d.Conference session_key, :waitUrl => HOLD_MUSIC_URL, :waitMethod => 'GET', :beep => false, :endConferenceOnExit => false
      end
    end.text
  end
  
  def fail
     xml =  Twilio::Verb.new do |v|
       v.say "The transfered call was not answered "
       v.hangup
    end
    xml.response    
  end
  
  def hangup
    Twilio::TwiML::Response.new { |r| r.Hangup }.text
  end
  
  def redirect_callee
    Twilio.connect(TWILIO_ACCOUNT, TWILIO_AUTH)
    Twilio::Call.redirect(call_attempt.sid, callee_transfer_index_url(:host => Settings.twilio_callback_host, :port => Settings.twilio_callback_port, session_key: session_key))        
  end
  
  def redirect_caller
    Twilio.connect(TWILIO_ACCOUNT, TWILIO_AUTH)
    Twilio::Call.redirect(caller_session.sid, caller_transfer_index_url(:host => Settings.twilio_callback_host, :port => Settings.twilio_callback_port, session_key: session_key, caller_session: caller_session_id))        
  end
  
  def self.aggregate(attempts)
    result = Hash.new
    attempts.each do |attempt|
      unless attempt.transfer.nil?
        if result[attempt.transfer.id].nil?
          result[attempt.transfer.id] = {label: attempt.transfer.label, number: 0}
        end
        result[attempt.transfer.id][:number] = result[attempt.transfer.id][:number]+1
      end

    end
    
    total = 0
    
    result.each_value do |value|
      total = total + value[:number]
    end  
    
    result.each_pair do |key, value|
      value[:percentage] = (value[:number] *100) / total
    end
      
    result
  end
  
  
end