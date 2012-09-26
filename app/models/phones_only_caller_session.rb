class PhonesOnlyCallerSession < CallerSession
  include Rails.application.routes.url_helpers  
  call_flow :state, :initial => :initial do    
    
      state :initial do
        event :callin_choice, :to => :read_choice
      end 
      
      
      state :read_choice do     
        after(:always)  {Resque.enqueue(ModeratorCallerJob, self.id, "publish_moderator_conference_started")}    
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
        after(:always)  {Resque.enqueue(ModeratorCallerJob, self.id, "publish_moderator_conference_started")}    
        event :start_conf, :to => :account_has_no_funds, :if => :funds_not_available?
        event :start_conf, :to => :time_period_exceeded, :if => :time_period_exceeded?
        event :start_conf, :to => :reassigned_campaign, :if => :caller_reassigned_to_another_campaign?        
        event :start_conf, :to => :choosing_voter_to_dial, :if => :preview?
        event :start_conf, :to => :choosing_voter_and_dial, :if => :power?
        event :start_conf, :to => :conference_started_phones_only_predictive, :if => :predictive?
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
          if the_call.voter_in_progress.present?
            xml_builder.Gather(:numDigits => 1, :timeout => 10, :action => flow_caller_url(self.caller, :session => self, event: "start_conf", :host => Settings.host, :port => Settings.port, :voter => the_call.voter_in_progress), :method => "POST", :finishOnKey => "5") do
              xml_builder.Say I18n.t(:read_voter_name, :first_name => the_call.voter_in_progress.FirstName, :last_name => the_call.voter_in_progress.LastName) 
            end
          else
            xml_builder.Say I18n.t(:campaign_has_no_more_voters)         
            xml_builder.Hangup   
          end
        end
                
      end
      
      state :choosing_voter_and_dial do
        event :start_conf, :to => :conference_started_phones_only
        before(:always) {select_voter(voter_in_progress)}
        response do |xml_builder, the_call|
          if voter_in_progress.present?
            xml_builder.Say "#{voter_in_progress.FirstName}  #{voter_in_progress.LastName}." 
            xml_builder.Redirect(flow_caller_url(caller, :session_id => id, :voter_id => voter_in_progress.id, event: "start_conf", :host => Settings.host, :port => Settings.port), :method => "POST")
          else
            xml_builder.Say I18n.t(:campaign_has_no_more_voters)
            xml_builder.Hangup
          end
        end
      end
      
      
      state :conference_started_phones_only do
        before(:always) {start_conference; Resque.enqueue(PreviewPowerDialJob, self.id, voter_in_progress.id) }
        event :gather_response, :to => :read_next_question, :if => :call_answered?
        event :gather_response, :to => :wrapup_call
        
        response do |xml_builder, the_call|
          xml_builder.Dial(:hangupOnStar => true, :action => flow_caller_url(caller, event: "gather_response", host:  Settings.host, port: Settings.port, session_id:  id, question: voter_in_progress.question_not_answered)) do
            xml_builder.Conference(session_key, :startConferenceOnEnter => false, :endConferenceOnExit => true, :beep => true, :waitUrl => HOLD_MUSIC_URL, :waitMethod => 'GET')
          end          
        end
        
      end
      
      state :conference_started_phones_only_predictive do
        before(:always) {start_conference}
        event :run_ot_of_phone_numbers, :to=> :campaign_out_of_phone_numbers        
        event :gather_response, :to => :read_next_question, :if => :call_answered?
        event :gather_response, :to => :wrapup_call


        response do |xml_builder, the_call|
          xml_builder.Dial(:hangupOnStar => true, :action => flow_caller_url(caller, event: "gather_response", :host => Settings.host, :port => Settings.port, :session_id => id)) do
            xml_builder.Conference(session_key, :startConferenceOnEnter => false, :endConferenceOnExit => true, :beep => true, :waitUrl => HOLD_MUSIC_URL, :waitMethod => 'GET')
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
      
      state :read_next_question do
        after(:always) {Resque.enqueue(ModeratorCallerJob, self.id, "publish_moderator_gathering_response")}
        event :submit_response, :to => :disconnected, :if => :disconnected?
        event :submit_response, :to => :wrapup_call, :if => :skip_all_questions?
        event :submit_response, :to => :voter_response
        
        response do |xml_builder, the_call|
          xml_builder.Gather(timeout: 60, finishOnKey: "*", action: flow_caller_url(caller, session_id: id, question_id: the_call.unanswered_question.id, event: "submit_response", host: Settings.host, port: Settings.port), method:  "POST") do
            xml_builder.Say the_call.unanswered_question.text
            the_call.unanswered_question.possible_responses.each do |response|
              xml_builder.Say "press #{response.keypad} for #{response.value}" unless (response.value == "[No response]")
            end
            xml_builder.Say I18n.t(:submit_results)
          end
        end
      end
      
      
      state :voter_response do
        event :next_question, :to => :read_next_question, :if => :more_questions_to_be_answered? 
        event :next_question, :to => :wrapup_call
        before(:always) {
          question = Question.find_by_id(question_id);          
          current_voter.answer(question, digit, self) if current_voter && question
          }
          
        response do |xml_builder, the_call|
          xml_builder.Redirect(flow_caller_url(self.caller, event: 'next_question', :host => Settings.host, :port => Settings.port, :session => id))          
        end        
          
      end
      
      state :wrapup_call do
        before(:always) {wrapup_call_attempt}
        event :next_call, :to => :ready_to_call
        response do |xml_builder, the_call|
          xml_builder.Redirect(flow_caller_url(self.caller, event: 'next_call', :host => Settings.host, :port => Settings.port, :session => id))          
        end        
        
      end
      
      
  end
  
  def skip_all_questions?
    digit == "999"
  end
  
  def wrapup_call_attempt
    attempt_in_progress.try(:update_attributes, {wrapup_time:  Time.now, voter_response_processed: true})
  end
  
  def publish_moderator_gathering_response
    Resque.enqueue(ModeratorCallJob, attempt_in_progress.id, "publish_moderator_response_submited")    
  end
  
  def unanswered_question
    current_voter.question_not_answered
  end
  
  def current_voter
    attempt_in_progress.voter
  end
  
  def more_questions_to_be_answered?
    !current_voter.question_not_answered.nil?
  end
  
  def call_answered?
    attempt_in_progress.try(:connecttime) != nil && more_questions_to_be_answered?
  end
  
  
  def select_voter(old_voter)
    voter = campaign.next_voter_in_dial_queue(old_voter.try(:id))
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
    
  def start_conference    
    begin
      update_attributes(:on_call => true, :available_for_call => true, :attempt_in_progress => nil)
    rescue ActiveRecord::StaleObjectError
      same_caller_session = CallerSession.find(self.id)
      same_caller_session.update_attributes(:on_call => true, :available_for_call => true, :attempt_in_progress => nil)
    end
  end
  
  def preview_campaign?
    campaign.type != Campaign::Type::Preview
  end
  
  
    
end