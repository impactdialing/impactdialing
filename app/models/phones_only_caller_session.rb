class PhonesOnlyCallerSession < CallerSession
  include Rails.application.routes.url_helpers  
  call_flow :state, :initial => :initial do    
    
      state :initial do
        event :callin_choice, :to => :read_choice
      end 
      
      
      state :read_choice do     
        event :read_instruction_options, :to => :instructions_options, :if => :pound_selected?
        event :read_instruction_options, :to => :time_period_exceeded, :if => :star_selected_and_time_period_exceeded?
        event :read_instruction_options, :to => :reassigned_campaign, :if => :star_selected_and_caller_reassigned_to_another_campaign?
        event :read_instruction_options, :to => :choosing_voter_to_dial, :if => :star_selected_and_preview?
        event :read_instruction_options, :to => :choosing_voter_and_dial, :if => :star_selected_and_power?
        event :read_instruction_options, :to => :conference_started_phones_only, :if => :star_selected_and_predictive?
        event :read_instruction_options, :to => :read_choice
        response do |xml_builder, the_call|
          xml_builder.gather(:numDigits => 1, :timeout => 10, :action => flow_caller_url(caller, session:  self, event: 'read_instruction_options' ,:host => Settings.host, :port => Settings.port), :method => "POST", :finishOnKey => "5") do
            xml_builder.say I18n.t(:caller_instruction_choice)
          end              
          
        end
      end
      
      state :instructions_options do   
        event :callin_choice, :to => :read_choice     
        response do |xml_builder, the_call|
          xml_builder.Say I18n.t(:phones_only_caller_instructions)
          xml_builder.Redirect(flow_caller_url(self.caller, event: 'callin_choice', :host => Settings.host, :port => Settings.port, :session => id))          
        end        
      end
      
      state :reassigned_campaign do
        event :callin_choice, :to => :read_choice
        response do |xml_builder, the_call|
          xml_builder.Say I18n.t(:re_assign_caller_to_another_campaign, :campaign_name => caller.campaign.name)
          xml_builder.Redirect(flow_caller_url(self.caller, event: 'callin_choice', :host => Settings.host, :port => Settings.port, :session => id, :Digits => "*"))
        end
      end
      
      state :choosing_voter_to_dial do                
        before(:always) {select_voter}
        response do |xml_builder, the_call|
          if voter_in_progress.present?
            xml_builder.gather(:numDigits => 1, :timeout => 10, :action => flow_caller_url(self.caller, :session => self, :host => Settings.host, :port => Settings.port, :voter => voter_in_progress), :method => "POST", :finishOnKey => "5") do
              xml_builder.Say I18n.t(:read_voter_name, :first_name => voter_in_progress.FirstName, :last_name => voter_in_progress.LastName) 
            end
          else
            xml_builder.say I18n.t(:campaign_has_no_more_voters)
          end
        end
                
      end
      
      state :choosing_voter_and_dial do
        event :start_conf, :to => :conference_started_phones_only
        before(:always) {select_voter}
        response do |xml_builder, the_call|
          if voter_in_progress.present?
            xml_builder.say "#{voter_in_progress.FirstName}  #{voter_in_progress.LastName}." 
            xml_builder.Redirect(flow_caller_url(caller, :session_id => id, :voter_id => voter_in_progress.id, :host => Settings.host, :port => Settings.port), :method => "POST")
          else
            xml_builder.say I18n.t(:campaign_has_no_more_voters)
          end
        end
      end
      
      state :time_period_exceeded do                        
        response do |xml_builder, the_call|          
          xml_builder.Say I18n.t(:campaign_time_period_exceed, :start_time => campaign.start_time.hour <= 12 ? "#{campaign.start_time.hour} AM" : "#{campaign.start_time.hour-12} PM", :end_time => campaign.end_time.hour <= 12 ? "#{campaign.end_time.hour} AM" : "#{campaign.end_time.hour-12} PM")
          xml_builder.Hangup
        end        
      end
      
      state :conference_started_phones_only do
        before(:always) {start_conference}
        
        response do |xml_builder, the_call|
          xml_builder.Dial(:hangupOnStar => true, :action => flow_caller_url(caller, event: "gather_response", :host => Settings.host, :port => Settings.port, :session_id => id)) do
            xml_builder.Conference(session_key, :startConferenceOnEnter => false, :endConferenceOnExit => true, :beep => true, :waitUrl => hold_call_url(:host => Settings.host, :port => Settings.port, :version => HOLD_VERSION), :waitMethod => 'GET')
          end          
        end
        
      end
      
      
      
  end
  
  def select_voter
    voter ||= campaign.next_voter_in_dial_queue
    update_attributes(voter_in_progress: voter)
  end
  
  
  def pound_selected?
    digit == "#"    
  end
  
  def star_selected_and_preview?
    digit == "*" && campaign.type == Campaign::Type::PREVIEW
  end
  
  def star_selected_and_time_period_exceeded?
    digit == "*" && time_period_exceeded?
  end
  
  def star_selected_and_power?
    digit == "*" && campaign.type == Campaign::Type::PROGRESSIVE
  end
  
  def star_selected_and_predictive?
    digit == "*" && campaign.type == Campaign::Type::PREDICTIVE
  end
  
  def star_selected_and_caller_reassigned_to_another_campaign?
    digit == "*" && caller_reassigned_to_another_campaign?
  end
  
  def assign_voter_to_caller
    voter ||= campaign.next_voter_in_dial_queue
  end
  
  def start_conference    
    begin
      update_attributes(:on_call => true, :available_for_call => true, :attempt_in_progress => nil)
    rescue ActiveRecord::StaleObjectError
      # end conf
    end
  end
  
  
  def instruction_choice_result(caller_choice, caller_session)
    if caller_choice == "*"
      campaign.is_preview_or_progressive ? caller_session.ask_caller_to_choose_voter : caller_session.start
    else
      ask_instructions_choice(caller_session)
    end
  end
  
  def preview_campaign?
    campaign.type != Campaign::Type::Preview
  end
  
  
  def instruction_options_twiml(xml_builder)
  end
  
    
end