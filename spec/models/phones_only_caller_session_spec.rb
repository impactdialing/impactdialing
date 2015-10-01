require 'rails_helper'

describe PhonesOnlyCallerSession, :type => :model do
  include Rails.application.routes.url_helpers
  def default_url_options
    {host: 'test.com'}
  end

  shared_context 'basic phone only caller session setup' do
    let(:script){ create(:script) }
    let(:campaign){ create(:power, script: script) }
    let(:caller_record){ create(:caller, campaign: campaign) }
    let(:voter){ create(:voter) }
    let(:question){ create(:question, script: script) }
    let(:caller_session) do
      create(:phones_only_caller_session, {
        caller: caller_record,
        on_call: true,
        available_for_call: false,
        campaign: campaign,
        question_id: question.id,
        script_id: script.id
      })
    end
    let(:dialed_call_storage) do
      instance_double('CallFlow::Call::Storage', {
        attributes: {}
      })
    end
    let(:dialed_call) do
      instance_double('CallFlow::Call::Dialed', {
        collect_response: nil,
        dispositioned: nil,
        storage: dialed_call_storage
      })
    end
    let(:params) do 
      {
        Digits: '1',
        question_number: 0,
        question_id: question.id,
        voter_id: 'lead-uuid'
      }
    end

    before do
      allow(caller_session).to receive(:dialed_call){ dialed_call }
    end
  end

  describe "initial" do
    describe "callin_choice " do
      before(:each) do
        @script           = create(:script)
        @campaign         = create(:preview, script: @script)
        @callers_campaign = create(:preview, script: @script)
        @caller           = create(:caller, campaign: @callers_campaign)
      end

      it "should render correct twiml" do
        caller_session = create(:phones_only_caller_session, caller: @caller, on_call: true, available_for_call: true, campaign: @campaign, script_id: @script.id)

        expect(caller_session.callin_choice).to gather({
          numDigits:   1,
          timeout:     10,
          action:      read_instruction_options_caller_url(@caller, session_id: caller_session.id),
          method:      "POST",
          finishOnKey: "5"
        }).with_nested_say("Press star to begin dialing or pound for instructions.")
      end
    end
  end

  describe "read_choice" do
    describe "readinstruction to instructions_options  if # selected" do
      before(:each) do
        @script = create(:script)
        @campaign =  create(:preview, script: @script)
        @callers_campaign =  create(:preview, script: @script)
        @caller = create(:caller, campaign: @callers_campaign)
      end

      it "should render correct twiml" do
        caller_session = create(:phones_only_caller_session, caller: @caller, on_call: true, available_for_call: true, campaign: @campaign, script_id: @script.id)
        params = {
          Digits: '#',
          question_number: 0
        }

        say_text = [
          "After these instructions, you will be placed on hold. ",
          "When someone answers the phone, the hold music will stop. ",
          "You usually won't hear the person say hello, so start talking immediately. ",
          "At the end of the conversation, do not hang up your phone. ",
          "Instead, press star to end the call, and you will be given instructions on ",
          "how to enter your call results."
        ].join

        expect(caller_session.read_choice(params)).to say(say_text).and_redirect(callin_choice_caller_url(@caller, session_id: caller_session.id))
      end
    end

    describe "readinstruction to read_choice  if wrong option selected" do
      before(:each) do
        @script = create(:script)
        @campaign =  create(:preview, script: @script)
        @callers_campaign =  create(:preview, script: @script)
        @caller = create(:caller, campaign: @callers_campaign)
      end


      it "should render twiml if wrong option selected" do
        caller_session = create(:phones_only_caller_session, caller: @caller, on_call: true, available_for_call: true, campaign: @campaign)
        RedisCallerSession.set_request_params(caller_session.id, {digit: "x", question_number: 0})

        expect(caller_session.read_choice).to gather({
          numDigits: 1,
          timeout: 10,
          action: read_instruction_options_caller_url(@caller, session_id: caller_session.id),
          method: "POST",
          finishOnKey: "5"
        }).with_nested_say("Press star to begin dialing or pound for instructions.")
      end
    end

    describe "present voter & options when * selected" do
      before(:each) do
        @script           = create(:script)
        @campaign         = create(:preview, script: @script)
        @callers_campaign = create(:preview, script: @script)
        @caller           = create(:caller, campaign: @campaign)
        @phone            = '1234567890'
        @voters           = [
          HashWithIndifferentAccess.new({id: 1, uuid: 'lead-uuid', phone: @phone, 'phone' => @phone, 'first_name' => '', 'last_name' => ''})
        ]
        allow(@campaign).to receive(:next_in_dial_queue).and_return({
          phone: @phone,
          leads: @voters
        })
      end

      it "should render correct twiml" do
        caller_session = create(:phones_only_caller_session, caller: @caller, on_call: true, available_for_call: true, campaign: @campaign, script_id: @script.id)
        params = {
          Digits: '*',
          question_number: 0
        }
        voter = @voters.first
        what_to_do = "Press pound to skip. Press star to dial."

        expect(caller_session.read_choice(params)).to gather({
          numDigits:   1,
          timeout:     10,
          action:      conference_started_phones_only_preview_caller_url(@caller, {
            phone: @phone,
            session_id: caller_session.id,
            voter_id: voter[:uuid]
          }),
          method:      "POST",
          finishOnKey: "5"
        }).with_nested_say(what_to_do)
      end
    end
  end

  describe "ready_to_call" do
    before do
      admin           = create(:user)
      @account        = admin.account
      @script         = create(:script, {account: @account})
      @preview        = create(:preview, script: @script, account: @account)
      @power          = create(:power, script: @script, account: @account)
    end

    shared_examples 'not fit to dial' do
      it 'not funded twiml' do
        @campaign.account.quota.update_attributes!(minutes_allowed: 0)

        caller_session = CallerSession.find @caller_session.id
        
        actual   = caller_session.ready_to_call
        expected = caller_session.account_has_no_funds_twiml

        expect(actual).to eq expected
      end

      it 'outside calling hours twiml' do
        Timecop.freeze(Date.today.end_of_day - 12.hours)
        @campaign.update_attributes(start_time: Time.now - 3.hours, end_time: Time.now - 2.hours)

        caller_session = CallerSession.find @caller_session.id

        actual   = caller_session.ready_to_call
        expected = caller_session.time_period_exceeded

        expect(actual).to eq expected
        Timecop.return
      end

      it 'account disabled' do
        @campaign.account.quota.update_attributes!(disable_calling: true)

        caller_session = CallerSession.find @caller_session.id
        actual         = caller_session.ready_to_call
        expected       = caller_session.calling_is_disabled_twiml

        expect(actual).to eq expected
      end
    end

    context 'in preview and power modes' do
      let(:campaign) do
        create(:power)
      end
      let(:caller_session) do
        create(:phones_only_caller_session, caller: create(:caller), campaign: campaign)
      end
      before do
        expect(caller_session).to receive(:campaign).at_least(:once).and_return(campaign)
      end
      after do
        allow(caller_session).to receive(:campaign).and_call_original
      end

      it 'returns twiml to redirect caller back to /caller/next_call and effectively retry this request' do
        expect(campaign).to receive(:next_in_dial_queue).and_raise(CallFlow::DialQueue::EmptyHousehold)

        ready_to_call_twiml         = caller_session.ready_to_call
        redirect_to_next_call_twiml = caller_session.twiml_redirect_to_next_call

        expect(ready_to_call_twiml).to eq (redirect_to_next_call_twiml)
      end
    end

    describe "choose voter for preview" do
      include FakeCallData

      before(:each) do
        @script           = create(:script)
        @campaign         = @preview
        @callers_campaign = @campaign
        @caller           = create(:caller, campaign: @campaign, account: @account)
        @caller_session   = create(:bare_caller_session, :phones_only, :available, {caller: @caller, campaign: @campaign, sid: 'caller-session-sid'})
        @voter            = create(:voter, campaign: @campaign)
      end

      it_behaves_like 'not fit to dial'

      it "should render twiml for preview when voters present" do
        call_attempt   = create(:call_attempt)
        caller_session = create(:phones_only_caller_session, caller: @caller, on_call: true, available_for_call: true, campaign: @campaign, script_id: @script.id)
        voter          = create(:voter, first_name:"first", last_name:"last", campaign: @campaign)

        expect(@campaign).to receive(:next_in_dial_queue).and_return({
          phone: voter.household.phone,
          leads: [HashWithIndifferentAccess.new(voter.attributes.merge(uuid: 'lead-uuid'))]
        })

        expect(caller_session.ready_to_call).to gather({
          numDigits: 1,
          timeout: 10,
          action: conference_started_phones_only_preview_caller_url(@caller, {
            phone: voter.household.phone,
            session_id: caller_session.id,
            voter_id: 'lead-uuid'
          }),
          method: "POST",
          finishOnKey: 5
        }).with_nested_say("first last. Press pound to skip. Press star to dial.")
      end

      it "should render twiml for preview when no voters present" do
        call_attempt   = create(:call_attempt)
        caller_session = create(:phones_only_caller_session, caller: @caller, on_call: true, available_for_call: true, campaign: @campaign, state: "ready_to_call", attempt_in_progress: call_attempt, script_id: @script.id)
        
        expect(@campaign).to receive(:next_in_dial_queue).and_return(nil)
        expect(caller_session.ready_to_call).to say("This campaign has run out of phone numbers.").and_hangup
      end
    end

    describe "choose voter for power" do
      include FakeCallData

      before(:each) do
        @script     = create(:script)
        @campaign   = create(:power, script: @script)
        @caller     = create(:caller, campaign: @campaign)
        @voter      = create(:voter, campaign: @campaign)
      end

      it "should render twiml for power when voters present" do
        call_attempt   = create(:call_attempt)
        caller_session = create(:phones_only_caller_session, caller: @caller, on_call: true, available_for_call: true, campaign: @campaign, script_id: @script.id)
        voter          = create(:voter, first_name:"first", last_name:"last")

        redirect_options = {method: "POST"}
        redirect_url     = conference_started_phones_only_power_caller_url(@caller, {
          phone: voter.household.phone,
          session_id: caller_session.id,
          voter_id: 'lead-uuid'
        })
        expect(@campaign).to receive(:next_in_dial_queue).and_return({
          phone: voter.household.phone,
          leads: [HashWithIndifferentAccess.new(voter.attributes.merge(uuid: 'lead-uuid'))]
        })
        expect(caller_session.ready_to_call).to say("first last.").and_redirect(redirect_url, redirect_options)
      end

      it "should render twiml for power when no voters present" do
        call_attempt   = create(:call_attempt)
        caller_session = create(:phones_only_caller_session, caller: @caller, on_call: true, available_for_call: true, campaign: @campaign, state: "ready_to_call", attempt_in_progress: call_attempt, script_id: @script.id)

        expect(@campaign).to receive(:next_in_dial_queue).and_return(nil)
        expect(caller_session.ready_to_call).to say("This campaign has run out of phone numbers.").and_hangup
      end
    end

    describe "start conference for predictive" do
      before(:each) do
        @script   = create(:script)
        @campaign = create(:predictive, script: @script)
        @caller   = create(:caller, campaign: @campaign)
      end

      it "should set on_call to true" do
        caller_session = create(:phones_only_caller_session, caller: @caller, on_call: true, available_for_call: true, campaign: @campaign, state: "ready_to_call", script_id: @script.id)
        expect(caller_session).to receive(:predictive?).and_return(true)
        caller_session.ready_to_call
        expect(caller_session.on_call).to be_truthy
      end

      it "should set available_for_call to true" do
        caller_session = create(:phones_only_caller_session, caller: @caller, on_call: true, available_for_call: true, campaign: @campaign, state: "ready_to_call", script_id: @script.id)
        expect(caller_session).to receive(:predictive?).and_return(true)
        caller_session.ready_to_call
        expect(caller_session.available_for_call).to be_truthy
      end

      it "should set attempt_in_progress to nil" do
        caller_session = create(:phones_only_caller_session, caller: @caller, on_call: true, available_for_call: true, campaign: @campaign, state: "ready_to_call", script_id: @script.id)
        expect(caller_session).to receive(:predictive?).and_return(true)
        caller_session.ready_to_call
        expect(caller_session.attempt_in_progress).to be_nil
      end

      it "render correct twiml" do
        caller_session = create(:phones_only_caller_session, caller: @caller, on_call: true, available_for_call: true, campaign: @campaign, state: "ready_to_call", script_id: @script.id)

        dial_options = {
          hangupOnStar: true,
          action: gather_response_caller_url(@caller.id, {
            session_id: caller_session.id,
            question_number: 0
          })
        }
        conference_options = {
          startConferenceOnEnter: false,
          endConferenceOnExit: true,
          beep: true,
          waitUrl: 'hold_music',
          waitMethod: 'GET'
        }

        expect(caller_session).to receive(:predictive?).and_return(true)
        expect(caller_session.ready_to_call).to dial_conference(dial_options, conference_options)
      end
    end
  end

  describe "choosing_voter_to_dial" do
    before(:each) do
      @script   = create(:script)
      @campaign = create(:preview, script: @script)
      @caller   = create(:caller, campaign: @campaign)
    end

    describe "skip voter if # selected" do
      it "should render correct twiml if pound selected" do
        voter          = create(:voter, first_name:"first", last_name:"last")
        caller_session = create(:phones_only_caller_session, caller: @caller, on_call: true, available_for_call: true, campaign: @campaign, script_id: @script.id)
        
        params = {
          Digits: '#',
          question_number: 0,
          voter_id: 'lead-uuid',
          phone: voter.household.phone
        }

        actual = caller_session.conference_started_phones_only_preview(params)
        url    = ready_to_call_caller_url(@caller, session_id: caller_session.id)
        expect(actual).to redirect(url)
      end
    end

    describe "start conference for preview if * selected" do
      before(:each) do
        @script   = create(:script)
        @campaign = create(:preview, script: @script)
        @caller   = create(:caller, campaign: @campaign)
        @voter    = create(:voter, campaign: @campaign)
      end

      it "render correct twiml" do
        question = create(:question, script: @script)
        caller_session = create(:phones_only_caller_session, caller: @caller, on_call: true, available_for_call: true, campaign: @campaign, script_id: @script.id)
        params = {
          Digits: '*',
          question_number: 0,
          phone: @voter.household.phone,
          voter_id: 'lead-uuid'
        } 

        expect(caller_session).to receive(:enqueue_call_flow).with(PreviewPowerDialJob, [caller_session.id, @voter.household.phone])

        actual       = caller_session.conference_started_phones_only_preview(params)
        dial_options = {
          hangupOnStar: true,
          action: gather_response_caller_url(@caller, question_number: 0, session_id: caller_session.id, voter_id: 'lead-uuid')
        }
        conference_options = {
          startConferenceOnEnter: false,
          endConferenceOnExit:    true,
          beep:                   true,
          waitUrl:                'hold_music',
          waitMethod:             'GET'
        }
        expect(actual).to dial_conference(dial_options, conference_options)
      end
    end

    describe "ready_to_call for preview if wrong option selected" do
      before(:each) do
        @script   = create(:script)
        @campaign = create(:preview, script: @script)
        @caller   = create(:caller, campaign: @campaign)
        @voter    = create(:voter)
      end

      it "should set caller state to ready_to_call if nothing selected" do
        voter          = create(:voter, first_name:"first", last_name:"last")
        caller_session = create(:phones_only_caller_session, caller: @caller, on_call: true, available_for_call: true, campaign: @campaign, script_id: @script.id)
        params = {
          question_number: 0,
          voter_id: 'lead-uuid',
          phone: voter.household.phone
        }

        actual         = caller_session.conference_started_phones_only_preview(params)
        gather_options = {
          numDigits: 1,
          timeout: 10,
          action: conference_started_phones_only_preview_caller_url(@caller, {
            phone: voter.household.phone,
            session_id: caller_session.id,
            voter_id: 'lead-uuid'
          }),
          method: 'POST',
          finishOnKey: 5
        }
        expect(actual).to gather(gather_options).with_nested_say("Press pound to skip. Press star to dial.")
      end
    end
  end

  describe "choosing_voter_and_dial" do
    describe "start conference for power" do
      before(:each) do
        @script   = create(:script)
        @campaign = create(:power, script: @script)
        @caller   = create(:caller, campaign: @campaign)
        @voter    = create(:voter, campaign: @campaign)
      end

      it "render correct twiml" do
        question       = create(:question, script: @script)
        caller_session = create(:phones_only_caller_session, caller: @caller, on_call: true, available_for_call: true, campaign: @campaign, script_id: @script.id)

        expect(caller_session).to receive(:enqueue_call_flow).with(PreviewPowerDialJob, [caller_session.id, @voter.household.phone])

        actual = caller_session.conference_started_phones_only_power({
          voter_id: 'lead-uuid',
          phone: @voter.household.phone
        })
        dial_options = {
          hangupOnStar: true,
          action: gather_response_caller_url(@caller, {
            question_number: 0,
            session_id: caller_session.id,
            voter_id: 'lead-uuid'
          })
        }
        conference_options = {
          startConferenceOnEnter: false,
          endConferenceOnExit: true,
          beep: true,
          waitUrl: 'hold_music',
          waitMethod: 'GET'
        }
        expect(actual).to dial_conference(dial_options, conference_options)
      end
    end
  end

  describe "conference_started_phones_only" do

    describe "gather_response to read_next_question" do
      before(:each) do
        @script   = create(:script)
        @campaign = create(:power, script: @script)
        @caller   = create(:caller, campaign: @campaign)
        @voter    = create(:voter)
        @question = create(:question, script: @script, text: "How do you like Impactdialing")
      end

      it "should render correct twiml" do
        call_attempt = create(:call_attempt, voter: @voter)
        caller_session = create(:phones_only_caller_session, caller: @caller, on_call: false, available_for_call: false, campaign: @campaign, script_id: @script.id)

        expect(caller_session).to receive(:call_answered?).and_return(true)

        expect(RedisQuestion).to receive(:get_question_to_read).with(@script.id, 0).and_return({"id"=> @question.id, "question_text"=> "How do you like Impactdialing"})

        expect(RedisPossibleResponse).to receive(:possible_responses).and_return([{"id"=>@question.id, "keypad"=> 1, "value"=>"Great"}, {"id"=>@question.id, "keypad"=>2, "value"=>"Super"}])
        
        gather_options = {
          timeout: 60,
          finishOnKey: '*',
          action: submit_response_caller_url(@caller, {
            question_id: @question.id,
            question_number: 0,
            session_id: caller_session.id,
            voter_id: 'lead-uuid'
          }),
          method: 'POST'
        }
        say_texts = [
          "How do you like Impactdialing",
          "press 1 for Great",
          "press 2 for Super",
          "Then press star to submit your result."
        ]
        params = {
          Digits: '1',
          voter_id: 'lead-uuid',
          question_number: 0
        }
        expect(caller_session.gather_response(params)).to gather(gather_options).with_nested_say(say_texts)
      end
    end
  end

  describe "conference_started_phones_only_predictive" do

    before(:each) do
      @script   = create(:script)
      @campaign = create(:predictive, script: @script)

      @phone            = '1234567890'
      @voters           = [
        {id: 1, phone: @phone, fields: {id: 1, phone: @phone, first_name: '', last_name: ''}}
      ]
      allow(@campaign).to receive(:next_in_dial_queue).and_return({
        phone: @phone,
        voters: @voters
      })
      @caller   = create(:caller, campaign: @campaign)
      @voter    = create(:voter)
      @question = create(:question, script: @script, text: "How do you like Impactdialing")
    end

    describe "gather_response to read_next_question" do
      it "should render correct twiml" do
        call_attempt = create(:call_attempt, voter: @voter)
        caller_session = create(:phones_only_caller_session, caller: @caller, on_call: false, available_for_call: false, campaign: @campaign, state: "conference_started_phones_only", question_id: @question.id, attempt_in_progress: call_attempt, question_number: 0, script_id: @script.id)

        gather_options = {
          timeout: 60,
          finishOnKey: '*',
          action: submit_response_caller_url(@caller, {
            question_id: @question.id,
            question_number: 0,
            session_id: caller_session.id,
            voter_id: 'lead-uuid'
          }),
          method: 'POST'
        }
        say_texts = [
          "How do you like Impactdialing",
          "press 1 for Great",
          "press 2 for Super",
          "Then press star to submit your result."
        ]
        params = {
          Digits: '1',
          voter_id: 'lead-uuid',
          question_number: 0
        }

        expect(RedisQuestion).to receive(:get_question_to_read).with(@script.id, caller_session.question_number).and_return({"id"=> @question.id, "question_text"=> "How do you like Impactdialing"})
        expect(RedisPossibleResponse).to receive(:possible_responses).and_return([{"id"=>@question.id, "keypad"=> 1, "value"=>"Great"}, {"id"=>@question.id, "keypad"=>2, "value"=>"Super"}])
        expect(caller_session).to receive(:call_answered?).and_return(true)
        expect(caller_session.gather_response(params)).to gather(gather_options).with_nested_say(say_texts)
      end
    end

    describe "run out of phone numbers" do
      it "should render hangup twiml" do
        caller_session = create(:phones_only_caller_session, caller: @caller, on_call: true, available_for_call: true, campaign: @campaign, state: "conference_started_phones_only_predictive")
        @campaign.caller_sessions << caller_session
        @campaign.save!

        expect(caller_session.campaign_out_of_phone_numbers).to say("This campaign has run out of phone numbers.").and_hangup
      end
    end
  end


  describe "read_next_question" do
    include_context 'basic phone only caller session setup'

    let(:selected_possible_response) do
      {
        'keypad' => '1',
        'id' => question.id,
        'possible_response_id' => '42'
      }
    end

    before do
      allow(caller_session).to receive(:redis_survey_response_from_digits){ selected_possible_response }
    end

    describe "disconnected" do
      it "render correct twiml" do
        params = {
          Digits: '1',
          question_number: 0,
          question_id: question.id,
          voter_id: 'lead-uuid'
        }
        expect(caller_session).to receive(:disconnected?).and_return(true)
        expect(caller_session.submit_response(params)).to hangup
      end
    end

    describe "wrapup_call" do
      let(:dialed_call_storage) do
        instance_double('CallFlow::Call::Storage', {
          attributes: {}
        })
      end
      before do
        allow(dialed_call).to receive(:storage){ dialed_call_storage }
        allow(dialed_call).to receive(:dispositioned)
      end

      describe 'normalizing survey responses' do
        before do
          allow(dialed_call_storage).to receive(:attributes).and_return({
            'question_1' => '42'
          })
        end
        it 'collects each storage attribute like "question_<id>" into hash like questions => {question_id => response_id}' do
          expect(dialed_call).to receive(:dispositioned).with({
            question: {
              '1' => '42'
            },
            lead: {
              id: 'lead-uuid'
            }
          })
          caller_session.wrapup_call(params)
        end
      end

      it "render correct twiml" do
        twiml = [
          "<?xml version=\"1.0\" encoding=\"UTF-8\"?>",
          "<Response><Redirect>",
          "http://#{Settings.twilio_callback_host}:#{Settings.twilio_callback_port}",
          "/caller/#{caller_record.id}/next_call?",
          "session_id=#{caller_session.id}",
          "</Redirect></Response>"
        ]
        expect(caller_session).to receive(:disconnected?).and_return(false)
        expect(caller_session).to receive(:skip_all_questions?).and_return(true)


        url = next_call_caller_url(caller_record, session_id: caller_session.id)
        expect(caller_session.submit_response(params)).to redirect(url)
      end
    end

    describe "voter response" do
      let(:phone){ Forgery(:address).clean_phone }
      let(:voters) do
        [
          {id: 1, phone: phone, first_name: '', last_name: ''}
        ]
      end
      before(:each) do
        allow(campaign).to receive(:next_in_dial_queue).and_return({
          phone: phone,
          leads: voters
        })
      end

      it "saves the answer " do
        params = {
          Digits: '1',
          question_number: 0,
          question_id: question.id
        }
        expect(caller_session).to receive(:disconnected?).and_return(false)
        expect(dialed_call).to receive(:collect_response).with(params, selected_possible_response)
        caller_session.submit_response(params)
      end

      it "should render correct twiml " do
        params = {
          Digits: '1',
          question_number: 0,
          question_id: question.id,
          voter_id: 'lead-uuid'
        }
        
        expect(caller_session).to receive(:disconnected?).and_return(false)
        url = gather_response_caller_url(caller_record, question_number: question.id, session_id: caller_session.id, voter_id: 'lead-uuid')
        expect(caller_session.submit_response(params)).to redirect(url)
      end
    end
  end

  describe "voter_response" do
    include_context 'basic phone only caller session setup'

    before do
      allow(dialed_call).to receive(:completed?){ true }
      allow(dialed_call).to receive(:answered_by_human?){ true }
    end

    describe "more_questions_to_be_answered" do
      before do
        allow(caller_session).to receive(:more_questions_to_be_answered?).and_return(true)
        allow(RedisQuestion).to receive(:get_question_to_read).with(script.id, 0).and_return({
          "id"=> question.id,
          "question_text"=> "How do you like Impactdialing"
        })
        allow(RedisPossibleResponse).to receive(:possible_responses).and_return([{
            "id"=>question.id, 
            "keypad"=> 1,
            "value"=>"Great"
          }, {
            "id"=>question.id,
            "keypad"=>2,
            "value"=>"Super"
          }
        ])
      end

      it "reads possible response values and keypad options" do
        params = {
          Digits: '1',
          question_number: 0,
          question_id: question.id,
          voter_id: 'lead-uuid'
        }

        gather_options = {
          timeout: 60,
          finishOnKey: '*',
          action: submit_response_caller_url(caller_record, {
            question_id:     question.id,
            question_number: 0,
            session_id:      caller_session.id,
            voter_id:        'lead-uuid'
          }),
          method: 'POST'
        }
        say_texts = [
          "How do you like Impactdialing",
          "press 1 for Great",
          "press 2 for Super",
          "Then press star to submit your result."
        ]

        expect(caller_session.gather_response(params)).to gather(gather_options).with_nested_say(say_texts)
      end

    end

    describe "no_more_questions_to_be_answered" do
      before do
        allow(caller_session).to receive(:more_questions_to_be_answered?).and_return(false)
      end

      it "redirects caller to next call" do
        expect(RedisStatus).to receive(:set_state_changed_time).with(campaign.id, "On hold",caller_session.id)
        url = next_call_caller_url(caller_record, session_id: caller_session.id)
        expect(caller_session.gather_response(params)).to redirect(url)
      end
    end

    describe 'caller hangs up without submitting a response (therefore, /gather_response is last end-point hit and params[:voter_id] is not set)' do
      it 'uses the voter_id from #dialed_call' do
        allow(dialed_call_storage).to receive(:[]).with(:lead_uuid){ 'lead-uuid' }
        allow(caller_session).to receive(:call_answered?){ false }

        expect(dialed_call).to receive(:dispositioned).with({
          question: {},
          lead: {id: 'lead-uuid'}
        })

        caller_session.gather_response(nil)
      end
    end
  end

end

# ## Schema Information
#
# Table name: `caller_sessions`
#
# ### Columns
#
# Name                        | Type               | Attributes
# --------------------------- | ------------------ | ---------------------------
# **`id`**                    | `integer`          | `not null, primary key`
# **`caller_id`**             | `integer`          |
# **`campaign_id`**           | `integer`          |
# **`endtime`**               | `datetime`         |
# **`starttime`**             | `datetime`         |
# **`sid`**                   | `string(255)`      |
# **`available_for_call`**    | `boolean`          | `default(FALSE)`
# **`voter_in_progress_id`**  | `integer`          |
# **`created_at`**            | `datetime`         |
# **`updated_at`**            | `datetime`         |
# **`on_call`**               | `boolean`          | `default(FALSE)`
# **`caller_number`**         | `string(255)`      |
# **`tCallSegmentSid`**       | `string(255)`      |
# **`tAccountSid`**           | `string(255)`      |
# **`tCalled`**               | `string(255)`      |
# **`tCaller`**               | `string(255)`      |
# **`tPhoneNumberSid`**       | `string(255)`      |
# **`tStatus`**               | `string(255)`      |
# **`tDuration`**             | `integer`          |
# **`tFlags`**                | `integer`          |
# **`tStartTime`**            | `datetime`         |
# **`tEndTime`**              | `datetime`         |
# **`tPrice`**                | `float`            |
# **`attempt_in_progress`**   | `integer`          |
# **`session_key`**           | `string(255)`      |
# **`state`**                 | `string(255)`      |
# **`type`**                  | `string(255)`      |
# **`digit`**                 | `string(255)`      |
# **`debited`**               | `boolean`          | `default(FALSE)`
# **`question_id`**           | `integer`          |
# **`caller_type`**           | `string(255)`      |
# **`question_number`**       | `integer`          |
# **`script_id`**             | `integer`          |
# **`reassign_campaign`**     | `string(255)`      | `default("no")`
#
# ### Indexes
#
# * `index_caller_sessions_debit`:
#     * **`debited`**
#     * **`caller_type`**
#     * **`tStartTime`**
#     * **`tEndTime`**
#     * **`tDuration`**
# * `index_caller_sessions_on_caller_id`:
#     * **`caller_id`**
# * `index_caller_sessions_on_campaign_id`:
#     * **`campaign_id`**
# * `index_caller_sessions_on_sid`:
#     * **`sid`**
# * `index_callers_on_call_group_by_campaign`:
#     * **`campaign_id`**
#     * **`on_call`**
# * `index_state_caller_sessions`:
#     * **`state`**
#
