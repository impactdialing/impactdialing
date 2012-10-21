class PhonesOnlyCallerSession < CallerSession
  call_flow :state, :initial => :initial do    
    
      state :initial do
        event :callin_choice, :to => :read_choice
      end 
      
      state all - [:initial] do
        event :end_conf, :to => :conference_ended
      end
      
      state :read_choice do     
        event :read_instruction_options, :to => :instructions_options, :if => :pound_selected?
        event :read_instruction_options, :to => :ready_to_call, :if => :star_selected?
        event :read_instruction_options, :to => :read_choice        
      end
      
      state :ready_to_call do  
        event :start_conf, :to => :account_has_no_funds, :if => :funds_not_available?
        event :start_conf, :to => :time_period_exceeded, :if => :time_period_exceeded?
        event :start_conf, :to => :reassigned_campaign, :if => :caller_reassigned_to_another_campaign?        
        event :start_conf, :to => :choosing_voter_to_dial, :if => :preview?
        event :start_conf, :to => :choosing_voter_and_dial, :if => :power?
        event :start_conf, :to => :conference_started_phones_only_predictive, :if => :predictive?
      end
      
      
      state :instructions_options do           
        event :callin_choice, :to => :read_choice     
      end
      
      state :reassigned_campaign do
        event :callin_choice, :to => :read_choice
      end
      
      state :choosing_voter_to_dial do   
        event :start_conf, :to => :conference_started_phones_only, :if => :star_selected?
        event :start_conf, :to => :skip_voter, :if => :pound_selected?  
        event :start_conf, :to => :ready_to_call                  
        before(:always) {select_voter(voter_in_progress)}
      end
      
      state :choosing_voter_and_dial do
        event :start_conf, :to => :conference_started_phones_only
        before(:always) {select_voter(voter_in_progress)}
      end
      
      
      state :conference_started_phones_only do
        before(:always) {start_conference; enqueue_call_flow(PreviewPowerDialJob, [self.id, voter_in_progress.id])}
        event :gather_response, :to => :read_next_question, :if => :call_answered?
        event :gather_response, :to => :wrapup_call
        
        response do |xml_builder, the_call|
          xml_builder.Dial(:hangupOnStar => true, :action => flow_caller_url(caller_id, event: "gather_response", host:  Settings.twilio_callback_host, port: Settings.twilio_callback_port, session_id:  self.id, question_number: 0)) do
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
          xml_builder.Dial(:hangupOnStar => true, :action => flow_caller_url(caller_id, event: "gather_response", :host => Settings.twilio_callback_host, :port => Settings.twilio_callback_port, :session_id => self.id, question_number: 0)) do
            xml_builder.Conference(session_key, :startConferenceOnEnter => false, :endConferenceOnExit => true, :beep => true, :waitUrl => HOLD_MUSIC_URL, :waitMethod => 'GET')
          end          
        end
        
      end
      
      
      state :skip_voter do
        before(:always) {voter_in_progress.skip}
        event :skipped_voter, :to => :ready_to_call
        response do |xml_builder, the_call|
          xml_builder.Redirect(flow_caller_url(caller_id, event: 'skipped_voter', :host => Settings.twilio_callback_host, :port => Settings.twilio_callback_port, :session_id => self.id))          
        end        
        
      end
      
      state :read_next_question do
        event :submit_response, :to => :disconnected, :if => :disconnected?
        event :submit_response, :to => :wrapup_call, :if => :skip_all_questions?
        event :submit_response, :to => :voter_response        
      end
      
      
      state :voter_response do
        event :next_question, :to => :read_next_question, :if => :more_questions_to_be_answered? 
        event :next_question, :to => :wrapup_call
        
        before(:always) {
          RedisPhonesOnlyAnswer.push_to_list(voter_in_progress.id, self.id, digit, question_id) if voter_in_progress
          }                          
      end
      
      state :wrapup_call do
        before(:always) {wrapup_call_attempt}
        event :run_ot_of_phone_numbers, :to=> :campaign_out_of_phone_numbers        
        event :next_call, :to => :ready_to_call
        response do |xml_builder, the_call|
          xml_builder.Redirect(flow_caller_url(caller_id, event: 'next_call', :host => Settings.twilio_callback_host, :port => Settings.twilio_callback_port, :session_id => self.id))          
        end        
      end
      
  end
    
  
  def skip_all_questions?
    redis_digit == "999"
  end
  
  def wrapup_call_attempt
    RedisStatus.set_state_changed_time(campaign.id, "On hold", self.id)
    unless attempt_in_progress.nil?
      RedisCallFlow.push_to_wrapped_up_call_list(attempt_in_progress.id, CallerSession::CallerType::PHONE);  
    end
  end
    
  
  
  def more_questions_to_be_answered?
    RedisQuestion.more_questions_to_be_answered?(script_id, redis_question_number)
  end
  
  def call_answered?
    attempt_in_progress.try(:connecttime) != nil && more_questions_to_be_answered?
  end
  
  
  def select_voter(old_voter)
    voter = campaign.next_voter_in_dial_queue(old_voter.try(:[], 'id'))
    unless voter.nil?
      self.update_attributes(voter_in_progress: voter)
    end
    voter    
  end
  
  
  def star_selected?
    redis_digit == "*"    
  end
  
  
  def pound_selected?
    redis_digit == "#"    
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
  
  def preview_campaign?
    campaign.type != Campaign::Type::Preview
  end
  
  def redis_digit
    RedisCallerSession.digit(self.id)
  end

  def redis_question_number
    RedisCallerSession.question_number(self.id).try(:to_i) || 0
  end
  
  def redis_question_id
    RedisCallerSession.question_id(self.id)
  end
  
end