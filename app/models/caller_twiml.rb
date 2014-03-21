module CallerTwiml

  module ClassMethods
  end

  module InstanceMethods

    def paused_twiml
      Twilio::TwiML::Response.new do |r|
        r.Say("Please enter your call results")
        r.Pause("length" => 600)
      end.text
    end

    def disconnected_twiml
      Twilio::TwiML::Response.new { |r| r.Hangup }.text
    end

    def connected_twiml
      Twilio::TwiML::Response.new do |r|
        r.Dial(:hangupOnStar => true, :action => pause_caller_url(caller_id, session_id:  id, host: DataCentre.call_back_host(data_centre), port:  Settings.twilio_callback_port, :protocol => "http://")) do
          r.Conference(session_key, startConferenceOnEnter: false, endConferenceOnExit:  true, beep: true, waitUrl: HOLD_MUSIC_URL, waitMethod:  'GET')
        end
      end.text
    end

    def subscription_limit_twiml
      Twilio::TwiML::Response.new do |r|
        r.Say("The maximum number of callers for this account has been reached. Wait for another caller to finish, or ask your administrator to upgrade your account.")
        r.Hangup
      end.text
    end

    def account_has_no_funds_twiml
      Twilio::TwiML::Response.new do |r|
        r.Say("There are no funds available in the account.  Please visit the billing area of the website to add funds to your account.")
        r.Hangup
      end.text
    end

    def calling_is_disabled_twiml
      Twilio::TwiML::Response.new do |response|
        response.Say("Calling has been disabled for this account. Please contact your account admin for assistance.")
        response.Hangup
      end.text
    end

    def time_period_exceeded_twiml
      Twilio::TwiML::Response.new do |r|
        r.Say I18n.t(:campaign_time_period_exceed, :start_time => campaign.start_time.hour <= 12 ? "#{campaign.start_time.hour} AM" : "#{campaign.start_time.hour-12} PM", :end_time => campaign.end_time.hour <= 12 ? "#{campaign.end_time.hour} AM" : "#{campaign.end_time.hour-12} PM")
        r.Hangup
      end.text
    end

    def conference_ended_twiml
      Twilio::TwiML::Response.new do |r|
        r.Hangup
      end.text
    end

    def campaign_out_of_phone_numbers_twiml
      Twilio::TwiML::Response.new do |r|
        r.Say I18n.t(:campaign_out_of_phone_numbers)
        r.Hangup
      end.text
    end

    def read_choice_twiml
      Twilio::TwiML::Response.new do |r|
        r.Gather(:numDigits => 1, :timeout => 10, :action => read_instruction_options_caller_url(caller_id, session_id:  self.id ,:host => DataCentre.call_back_host(data_centre), :port => Settings.twilio_callback_port, :protocol => "http://"), :method => "POST", :finishOnKey => "5") do
          r.Say I18n.t(:caller_instruction_choice)
        end
      end.text
    end

    def ready_to_call_twiml
      Twilio::TwiML::Response.new do |r|
        r.Redirect(ready_to_call_caller_url(caller_id, :host => DataCentre.call_back_host(data_centre), :port => Settings.twilio_callback_port, :protocol => "http://", :protocol => "http://", :session_id => self.id))
      end.text
    end

    def instructions_options_twiml
      Twilio::TwiML::Response.new do |r|
        r.Say I18n.t(:phones_only_caller_instructions)
        r.Redirect(callin_choice_caller_url(caller_id, :host => DataCentre.call_back_host(data_centre), :port => Settings.twilio_callback_port, :protocol => "http://", :session_id => self.id))
      end.text
    end

    def reassigned_campaign_twiml
      Twilio::TwiML::Response.new do |r|
        r.Say I18n.t(:re_assign_caller_to_another_campaign, :campaign_name => caller.campaign.name)
        r.Redirect(flow_caller_url(caller_id, event: 'callin_choice', :host => DataCentre.call_back_host(data_centre), :port => Settings.twilio_callback_port, :protocol => "http://", :session_id => self.id, :Digits => "*"))
      end.text
    end

    def choosing_voter_to_dial_twiml
      Twilio::TwiML::Response.new do |r|
        unless self.voter_in_progress.nil?
          r.Gather(:numDigits => 1, :timeout => 10, :action => conference_started_phones_only_preview_caller_url(caller_id, :session_id => self.id, :host => DataCentre.call_back_host(data_centre), :port => Settings.twilio_callback_port, :protocol => "http://", :voter => self.voter_in_progress.id), :method => "POST", :finishOnKey => "5") do
            r.Say I18n.t(:read_voter_name, :first_name => self.voter_in_progress.first_name, :last_name => self.voter_in_progress.last_name)
          end
        else
          r.Say I18n.t(:campaign_has_no_more_voters)
          r.Hangup
        end
      end.text
    end

    def choosing_voter_and_dial_twiml
      Twilio::TwiML::Response.new do |r|
        unless voter_in_progress.nil?
          r.Say "#{self.voter_in_progress.first_name}  #{self.voter_in_progress.last_name}."
          r.Redirect(conference_started_phones_only_power_caller_url(caller_id, :session_id => self.id, :voter_id => voter_in_progress.id, :host => DataCentre.call_back_host(data_centre), :port => Settings.twilio_callback_port, :protocol => "http://"), :method => "POST")
        else
          r.Say I18n.t(:campaign_has_no_more_voters)
          r.Hangup
        end
      end.text
    end

    def conference_started_phones_only_twiml
      Twilio::TwiML::Response.new do |r|
        r.Dial(:hangupOnStar => true, :action => gather_response_caller_url(caller_id, host:  DataCentre.call_back_host(data_centre), port: Settings.twilio_callback_port, :protocol => "http://", session_id:  self.id, question_number: 0)) do
          r.Conference(session_key, :startConferenceOnEnter => false, :endConferenceOnExit => true, :beep => true, :waitUrl => HOLD_MUSIC_URL, :waitMethod => 'GET')
        end
      end.text
    end

    def conference_started_phones_only_predictive_twiml
      Twilio::TwiML::Response.new do |r|
        r.Dial(:hangupOnStar => true, :action => gather_response_caller_url(caller_id, :host => DataCentre.call_back_host(data_centre), :port => Settings.twilio_callback_port, :protocol => "http://", :session_id => self.id, question_number: 0)) do
          r.Conference(session_key, :startConferenceOnEnter => false, :endConferenceOnExit => true, :beep => true, :waitUrl => HOLD_MUSIC_URL, :waitMethod => 'GET')
        end
      end.text
    end

   def skip_voter_twiml
     Twilio::TwiML::Response.new do |r|
       r.Redirect(ready_to_call_caller_url(caller_id, :host => DataCentre.call_back_host(data_centre), :port => Settings.twilio_callback_port, :protocol => "http://", :session_id => self.id))
     end.text
   end


   def read_next_question_twiml
     Twilio::TwiML::Response.new do |r|
       question = RedisQuestion.get_question_to_read(script_id, redis_question_number)
       r.Gather(timeout: 60, finishOnKey: "*", action: submit_response_caller_url(caller_id, session_id: self.id, question_id: question['id'], question_number: redis_question_number, host: DataCentre.call_back_host(data_centre), port: Settings.twilio_callback_port, protocol: "http://"), method:  "POST") do
         r.Say question['question_text']
         RedisPossibleResponse.possible_responses(question['id']).each do |response|
           r.Say "press #{response['keypad']} for #{response['value']}" unless (response['value'] == "[No response]")
         end
         r.Say I18n.t(:submit_results)
       end
     end.text
  end

  def voter_response_twiml
    Twilio::TwiML::Response.new do |r|
      r.Redirect(next_question_caller_url(caller_id, :host => DataCentre.call_back_host(data_centre), :port => Settings.twilio_callback_port, :protocol => "http://", :session_id => self.id, question_number: redis_question_number+1))
    end.text
  end

  def wrapup_call_twiml
    Twilio::TwiML::Response.new do |r|
      r.Redirect(next_call_caller_url(caller_id, :host => DataCentre.call_back_host(data_centre), :port => Settings.twilio_callback_port, :protocol => "http://", :session_id => self.id))
    end.text

  end
 end
  def self.included(receiver)
    receiver.extend         ClassMethods
    receiver.send :include, InstanceMethods
  end

end
