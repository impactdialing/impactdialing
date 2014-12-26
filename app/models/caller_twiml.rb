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
        r.Dial(:hangupOnStar => true, :action => pause_caller_url(caller_id, default_twiml_url_params)) do
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
        r.Gather(:numDigits => 1, :timeout => 10, :action => read_instruction_options_caller_url(caller_id, default_twiml_url_params), :method => "POST", :finishOnKey => "5") do
          r.Say I18n.t(:caller_instruction_choice)
        end
      end.text
    end

    def ready_to_call_twiml
      Twilio::TwiML::Response.new do |r|
        r.Redirect(ready_to_call_caller_url(caller_id, default_twiml_url_params))
      end.text
    end

    def instructions_options_twiml
      Twilio::TwiML::Response.new do |r|
        r.Say I18n.t(:phones_only_caller_instructions)
        r.Redirect(callin_choice_caller_url(caller_id, default_twiml_url_params))
      end.text
    end

    def reassigned_campaign_twiml
      Twilio::TwiML::Response.new do |r|
        r.Say I18n.t(:re_assign_caller_to_another_campaign, :campaign_name => caller.campaign.name)
        r.Redirect(flow_caller_url(caller_id, event: 'callin_choice', :host => DataCentre.call_back_host(data_centre), :port => Settings.twilio_callback_port, :protocol => "http://", :session_id => self.id, :Digits => "*"))
      end.text
    end

    def conference_started_url_params(voter_id, phone)
      default_twiml_url_params.merge({
        voter_id: voter_id,
        phone: phone
      })
    end

    def question_url_params(n = 0, voter_id = nil)
      params = {question_number: n}
      params.merge!({voter_id: voter_id}) if voter_id.present?
      default_twiml_url_params.merge(params)
    end

    def next_question_url_params(voter_id = nil)
      question_url_params(redis_question_number + 1, voter_id)
    end

    def default_twiml_url_params
      {
        session_id: self.id,
        host:       Settings.twilio_callback_host,
        port:       Settings.twilio_callback_port,
        protocol:   "http://"
      }
    end

    def choosing_voter_to_dial_twiml(voter_id, phone, first_name = nil, last_name = nil)
      what_to_do = "Press pound to skip. Press any other key to dial."
      what_to_do = "#{first_name} #{last_name}. #{what_to_do}" if first_name and last_name
      Twilio::TwiML::Response.new do |r|
        r.Gather({
          numDigits:   1,
          timeout:     10,
          action:      conference_started_phones_only_preview_caller_url(caller_id, conference_started_url_params(voter_id, phone)),
          method:      "POST",
          finishOnKey: "5"
        }) do
          r.Say what_to_do
        end
      end.text
    end

    def choosing_voter_and_dial_twiml(voter_id, phone, first_name, last_name)
      Twilio::TwiML::Response.new do |r|
        r.Say "#{first_name} #{last_name}."
        r.Redirect(conference_started_phones_only_power_caller_url(caller_id, conference_started_url_params(voter_id, phone)), {
          :method => "POST"
        })
      end.text
    end

    def conference_started_phones_only_twiml(voter_id, phone)
      Twilio::TwiML::Response.new do |r|
        r.Dial(:hangupOnStar => true, :action => gather_response_caller_url(caller_id, question_url_params(0, voter_id).merge(question_number: 0))) do
          r.Conference(session_key, :startConferenceOnEnter => false, :endConferenceOnExit => true, :beep => true, :waitUrl => HOLD_MUSIC_URL, :waitMethod => 'GET')
        end
      end.text
    end

    def conference_started_phones_only_predictive_twiml
      Twilio::TwiML::Response.new do |r|
        r.Dial(:hangupOnStar => true, :action => gather_response_caller_url(caller_id, question_url_params(0))) do
          r.Conference(session_key, :startConferenceOnEnter => false, :endConferenceOnExit => true, :beep => true, :waitUrl => HOLD_MUSIC_URL, :waitMethod => 'GET')
        end
      end.text
    end

   def skip_voter_twiml
     Twilio::TwiML::Response.new do |r|
       r.Redirect(ready_to_call_caller_url(caller_id, default_twiml_url_params))
     end.text
   end

   def read_next_question_twiml(voter_id)
    question = RedisQuestion.get_question_to_read(script_id, redis_question_number)
    action   = submit_response_caller_url(caller_id, default_twiml_url_params.merge({
                  question_id:     question['id'],
                  question_number: redis_question_number,
                  voter_id:        voter_id
                }))
    Twilio::TwiML::Response.new do |r|
      r.Gather({timeout: 60, finishOnKey: "*", action: action, method:  "POST"}) do
        r.Say question['question_text']
        RedisPossibleResponse.possible_responses(question['id']).each do |response|
          r.Say "press #{response['keypad']} for #{response['value']}" unless (response['value'] == "[No response]")
        end
        r.Say I18n.t(:submit_results)
      end
    end.text
  end

  def redirect_to_next_question_twiml(voter_id)
    params = next_question_url_params(voter_id)
    Twilio::TwiML::Response.new do |r|
      r.Redirect(gather_response_caller_url(caller_id, params))
    end.text
  end

  def wrapup_call_twiml
    Twilio::TwiML::Response.new do |r|
      r.Redirect(next_call_caller_url(caller_id, default_twiml_url_params))
    end.text
  end
 end
  def self.included(receiver)
    receiver.extend         ClassMethods
    receiver.send :include, InstanceMethods
  end

end
