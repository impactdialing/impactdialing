class PhonesOnlyCallerSession < CallerSession
  include Rails.application.routes.url_helpers  
  call_flow :state, :initial => :initial do    
    
      state :initial do
        event :callin_choice, :to => :read_choice
      end 
      
      
      state :read_choice do     
        event :read_instruction_options, :to => :instructions_options, :if => :pound_selected?
        event :read_instruction_options, :to => :ready_to_call, :if => :star_selected?
        event :read_instruction_options, :to => :read_choice
        
        response do |xml_builder, the_call|
          xml_builder.Gather(:numDigits => 1, :timeout => 10, :action => flow_caller_url(caller, session:  self, event: 'read_instruction_options' ,:host => Settings.host, :port => Settings.port), :method => "POST", :finishOnKey => "5") do
            xml_builder.Say I18n.t(:caller_instruction_choice)
          end              
          
        end
      end
      
      state :ready_to_call do        
        event :start_conf, :to => :time_period_exceeded, :if => :time_period_exceeded?
        event :start_conf, :to => :reassigned_campaign, :if => :caller_reassigned_to_another_campaign?
        event :start_conf, :to => :choosing_voter_to_dial, :if => :preview?
        event :start_conf, :to => :choosing_voter_and_dial, :if => :power?
        event :start_conf, :to => :conference_started_phones_only, :if => :predictive?
        response do |xml_builder, the_call|
          xml_builder.Redirect(flow_caller_url(self.caller, event: 'start_conf', :host => Settings.host, :port => Settings.port, :session => id))          
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
        event :start_conf, :to => :conference_started_phones_only, :if => :star_selected?
        event :start_conf, :to => :skip_voter, :if => :pound_selected?  
        event :start_conf, :to => :ready_to_call
                  
        before(:always) {select_voter(voter_in_progress)}
        response do |xml_builder, the_call|
          if voter_in_progress.present?
            xml_builder.Gather(:numDigits => 1, :timeout => 10, :action => flow_caller_url(self.caller, :session => self, event: "gather_response", :host => Settings.host, :port => Settings.port, :voter => voter_in_progress), :method => "POST", :finishOnKey => "5") do
              xml_builder.Say I18n.t(:read_voter_name, :first_name => voter_in_progress.FirstName, :last_name => voter_in_progress.LastName) 
            end
          else
            xml_builder.Say I18n.t(:campaign_has_no_more_voters)
          end
        end
                
      end
      
      state :choosing_voter_and_dial do
        event :start_conf, :to => :conference_started_phones_only
        before(:always) {select_voter(voter_in_progress)}
        response do |xml_builder, the_call|
          if voter_in_progress.present?
            xml_builder.Say "#{voter_in_progress.FirstName}  #{voter_in_progress.LastName}." 
            xml_builder.Redirect(flow_caller_url(caller, :session_id => id, :voter_id => voter_in_progress.id, :host => Settings.host, :port => Settings.port), :method => "POST")
          else
            xml_builder.Say I18n.t(:campaign_has_no_more_voters)
          end
        end
      end
      
      state :conference_started_phones_only do
        before(:always) {start_conference; preview_dial(voter_in_progress)}
        event :gather_response, :to => :voter_response
        
        response do |xml_builder, the_call|
          xml_builder.Dial(:hangupOnStar => true, :action => flow_caller_url(caller, event: "gather_response", :host => Settings.host, :port => Settings.port, :session_id => id)) do
            xml_builder.Conference(session_key, :startConferenceOnEnter => false, :endConferenceOnExit => true, :beep => true, :waitUrl => hold_call_url(:host => Settings.host, :port => Settings.port, :version => HOLD_VERSION), :waitMethod => 'GET')
          end          
        end
        
      end
      
      
      state :skip_voter do
        before(:always) {voter_in_progress.skip}
        event :skipped_voter, :to => :ready_to_call
        response do |xml_builder, the_call|
          xml_builder.Redirect(flow_caller_url(self.caller, event: 'skipped_voter', :host => Settings.host, :port => Settings.port, :session => id))          
        end        
        
      end
      
      
      state :voter_response do
        
      end
      
  end
    
  
  def select_voter(voter)
    voter ||= campaign.next_voter_in_dial_queue(voter_in_progress)
    update_attributes(voter_in_progress: voter)
  end
  
  def star_selected?
    digit == "*"    
  end
  
  
  def pound_selected?
    digit == "#"    
  end
  
  def preview?
    campaign.type == Campaign::Type::PREVIEW
  end
  
  
  def power?
    campaign.type == Campaign::Type::PROGRESSIVE
  end
  
  def predictive?
    campaign.type == Campaign::Type::PREDICTIVE
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
  
  def preview_campaign?
    campaign.type != Campaign::Type::Preview
  end
  
  
    
end