require "spec_helper"
require 'fiber'
describe Voter, :type => :model do
  include Rails.application.routes.url_helpers

  describe 'Voter::Status' do
    it 'defines NOTCALLED as "not called"' do
      expect(Voter::Status::NOTCALLED).to eq 'not called'
    end
    it 'defines RETRY as "retry"' do
      expect(Voter::Status::RETRY).to eq 'retry'
    end
    it 'defines SKIPPED as "skipped"' do
      expect(Voter::Status::SKIPPED).to eq 'skipped'
    end
  end

  describe '#do_not_call_back?' do
    let(:voter){ build(:voter) }
    it 'returns false when status == NOTCALLED' do
      expect(voter.status).to eq Voter::Status::NOTCALLED
      expect(voter.do_not_call_back?).to be_falsey
    end

    it 'returns false when call_back == true' do
      voter.call_back = true
      voter.status    = CallAttempt::Status::SUCCESS
      expect(voter.do_not_call_back?).to be_falsey
    end

    it 'returns false when status == RETRY' do
      voter.status = Voter::Status::RETRY
      expect(voter.do_not_call_back?).to be_falsey
    end

    it 'returns true when status != NOTCALLED and status != RETRY and call_back == false' do
      voter.status = CallAttempt::Status::SUCCESS
      expect(voter.do_not_call_back?).to be_truthy
    end
  end

  describe '#dispositioned(call_attempt)' do
    let(:voter) do
      create(:voter, caller_session_id: 42)
    end
    let(:call_attempt) do
      create(:call_attempt, {
        status: CallAttempt::Status::SUCCESS,
        caller: create(:caller, campaign: voter.campaign),
        campaign: voter.campaign
      })
    end

    it 'sets status to call_attempt.status' do
      voter.dispositioned(call_attempt)
      expect(voter.status).to eq call_attempt.status
    end

    it 'sets caller_id to call_attempt.caller_id' do
      voter.dispositioned(call_attempt)
      expect(voter.caller_id).to eq call_attempt.caller_id
    end

    it 'unsets caller_session_id' do
      voter.dispositioned(call_attempt)
      expect(voter.caller_session_id).to be_nil
    end

    context 'when Voter should not be contacted again' do
      let(:dial_queue_instance) do
        double('DialQueueInstance', {
          remove: nil
        })
      end
      before do
        allow(CallFlow::DialQueue).to receive(:new){ dial_queue_instance }
        allow(voter).to receive(:do_not_call_back?){ true }
      end
      it 'is removed from the dial queue' do
        expect(dial_queue_instance).to receive(:remove).with(voter)
        voter.dispositioned(call_attempt)
      end
    end
  end

  describe '#info' do
    include FakeCallData
    include ERB::Util

    shared_context 'Voter#info setup' do
      def setup_custom_fields(account, script, voter, voter_fields)
        script.update_attributes!(voter_fields: voter_fields)

        custom_field = create(:custom_voter_field, {
          account: account,
          name: 'ImportedFromOldSystem'
        })
        create(:custom_voter_field_value, {
          voter: voter,
          custom_voter_field: custom_field
        })
        custom_field = create(:custom_voter_field, {
          account: account,
          name: 'MoreInfo'
        })
        create(:custom_voter_field_value, {
          voter: voter,
          custom_voter_field: custom_field,
          value: 'test.com'
        })
      end

      let(:admin) do
        create(:user)
      end
      let(:account) do
        admin.account
      end
      let(:script_questions_campaign) do
        create_campaign_with_script(:bare_preview, account)
      end
      let(:script) do
        script_questions_campaign.first
      end
      let(:campaign) do
        script_questions_campaign.last
      end
      let(:voter) do
        create(:voter, {
          account: account,
          campaign: campaign
        })
      end
      let(:expected_fields) do
        one = voter.attributes.reject{|k,v| k =~ /(created|updated)_at/}
        two = {}
        one.each{|k,v| two[html_escape(k)] = html_escape(v.to_s)}
        two.merge({
          'email' => "<a target=\"_blank\" href=\"mailto:#{voter.email}\">#{voter.email}</a>"
        })
      end
    end

    shared_context 'Voter#info with custom fields' do
      let(:voter_fields) do
        "[\"Phone\", \"FirstName\", \"LastName\", \"Email\", \"ImportedFromOldSystem\", \"MoreInfo\"]"
      end
    end

    shared_examples 'non-autolinked fields' do
      include ERB::Util

      it 'html encodes all `fields`' do
        voter.first_name = '<script>alert("blah");</script>'
        voter.save!
        actual = voter.info[:fields]['first_name']
        expect(actual).to eq html_escape(voter.first_name)
      end

      it 'html encodes all `custom_fields`' do
        field = CustomVoterField.where(name: 'ImportedFromOldSystem').first
        value = field.custom_voter_field_values.first
        value.value = '<script>alert("blah");</script>'
        value.save!
        actual = voter.info[:custom_fields]['ImportedFromOldSystem']
        expect(actual).to eq html_escape(value.value)
      end
    end

    shared_examples 'voter info with fields' do
      before do
        expect(expected_fields).to_not be_empty
      end

      it 'returns a hash with key :fields, value Voter#attributes sans created_at & updated_at' do
        expect(voter.info[:fields]).to eq expected_fields
      end

      it 'always flags Phone number for display' do
        expect(voter.info['Phone_flag']).to be_truthy
      end

      it 'flags Script#voter_fields for display' do
        script.update_attributes!(voter_fields: '["FirstName"]')
        flags = voter.info.reject{|k,v| k !~ /\w+_flag/ or k =~ /Phone_flag/}
        expect(voter.info['FirstName_flag']).to be_truthy
      end
    end

    include_context 'Voter#info setup'
    it_behaves_like 'voter info with fields'

    describe 'voter info with autolinking of URLs and emails' do
      include_context 'Voter#info with custom fields'

      before do
        setup_custom_fields(account, script, voter, voter_fields)
      end

      it 'converts plain text email addresses (e.g. joe@test.com) to links' do
        expect(voter.info[:fields]['email']).to eq "<a target=\"_blank\" href=\"mailto:#{voter.email}\">#{voter.email}</a>"
      end

      it 'converts plain text URLs (e.g. www.test.com or test.com) to links' do
        expect(voter.info[:custom_fields]['MoreInfo']).to eq "<a target=\"_blank\" href=\"http://test.com\">test.com</a>"
      end

      it 'makes best effort to ignore typos that look like domains' do
        voter.email = 'No-email.Please use phone'
        voter.save!
        expect(voter.info[:fields]['email']).to eq voter.email
      end

      it 'makes best effort to ignore typos that look like emails' do
        voter.email = 'Holla-@twit'
        voter.save!
        expect(voter.info[:fields]['email']).to eq voter.email
      end

      it 'performs html escaping on all fields'

      it 'performs html escaping on all custom fields'
    end

    context 'Script#voter_fields is nil' do
      before do
        expect(script.voter_fields).to be_nil
      end

      it_behaves_like 'voter info with fields'
    end

    context 'Script#voter_fields is not nil' do
      context 'Script#selected_custom_fields is nil' do
        before do
          expect(script.selected_custom_fields).to be_nil
        end

        it_behaves_like 'voter info with fields'
      end

      context 'Script#selected_custom_fields is not nil' do
        include_context 'Voter#info with custom fields'

        before do
          setup_custom_fields(account, script, voter, voter_fields)
        end

        it_behaves_like 'voter info with fields'
        it_behaves_like 'non-autolinked fields'

        it 'includes custom fields for showing under the :custom_fields key' do
          expect(voter.info[:custom_fields].keys).to include 'ImportedFromOldSystem'
        end
      end
    end
  end

  it "gives remaining voters to count" do
    campaign = create(:campaign)
    no_answr_voter = create(:voter, :campaign => campaign, :status=> CallAttempt::Status::NOANSWER)
    busy_voter = create(:voter, :campaign => campaign, :status=> CallAttempt::Status::BUSY)
    abandon_voter = create(:voter, :campaign => campaign, :status=> CallAttempt::Status::ABANDONED)
    schedule_voter = create(:voter, :campaign => campaign, :status=> CallAttempt::Status::SCHEDULED, :call_back => true)
    not_called_voter = create(:voter, :campaign => campaign, :status=> Voter::Status::NOTCALLED)
    failed_voter = create(:voter, :campaign => campaign, :status=> CallAttempt::Status::FAILED, :call_back => true)
    ready_voter = create(:voter, :campaign => campaign, :status=> CallAttempt::Status::READY)
    success_voter = create(:voter, :campaign => campaign, :status=> CallAttempt::Status::SUCCESS)
    expect(Voter.remaining_voters_for_campaign(campaign)).to have(6).items
  end

  it "lists voters not called" do
    voter1 = create(:voter, :campaign => create(:campaign), :status=> Voter::Status::NOTCALLED)
    voter2 = create(:voter, :campaign => create(:campaign), :status=> Voter::Status::NOTCALLED)
    create(:voter, :campaign => create(:campaign), :status=> "Random")
    expect(Voter.by_status(Voter::Status::NOTCALLED)).to include(voter1)
    expect(Voter.by_status(Voter::Status::NOTCALLED)).to include(voter2)
  end

  it "returns only active voters" do
    active_voter = create(:voter, :active => true)
    inactive_voter = create(:voter, :active => false)
    expect(Voter.active).to include(active_voter)
  end

  it "returns voters from an enabled list" do
    voter_from_enabled_list = create(:voter, :voter_list => create(:voter_list, :enabled => true))
    voter_from_disabled_list = create(:voter, :disabled, :voter_list => create(:voter_list, :enabled => false))
    expect(Voter.enabled).to include(voter_from_enabled_list)
  end

  it "returns voters that have responded" do
    create(:voter)
    3.times { create(:voter, :result_date => Time.now) }
    expect(Voter.answered.size).to eq(3)
  end

  it "returns voters that have responded within a date range" do
    create(:voter)
    v1 = create(:voter, :result_date => DateTime.now)
    v2 = create(:voter, :result_date => 1.day.ago)
    v3 = create(:voter, :result_date => 2.days.ago)
    expect(Voter.answered_within(2.days.ago, 0.days.ago)).to eq([v1, v2, v3])
    expect(Voter.answered_within(2.days.ago, 1.day.ago)).to eq([v2, v3])
    expect(Voter.answered_within(1.days.ago, 1.days.ago)).to eq([v2])
  end

  it "returns voters who have responded within a time range" do
    v1 = create(:voter, :result_date => Time.new(2012, 2, 14, 10))
    v2 = create(:voter, :result_date => Time.new(2012, 2, 14, 15))
    v3 = create(:voter, :result_date => Time.new(2012, 2, 14, 20))
    expect(Voter.answered_within_timespan(Time.new(2012, 2, 14, 10), Time.new(2012, 2, 14, 12))).to eq([v1])
    expect(Voter.answered_within_timespan(Time.new(2012, 2, 14, 12), Time.new(2012, 2, 14, 23, 59, 59))).to eq([v2, v3])
    expect(Voter.answered_within_timespan(Time.new(2012, 2, 14, 0), Time.new(2012, 2, 14, 9, 59, 59))).to eq([])
  end

  describe 'calculating number of voters left to dial in given voter list' do
    def setup_voters(n=10, voter_opts={})
      account = create(:account)
      campaign = create(:power, {account: account})
      vopt = voter_opts.merge({
        campaign: campaign,
        enabled: [:list]
      })
      create_list(:voter, n, vopt)
      expect(Voter.count).to eq n
      @voters = Voter.all
      last_call_time = 20.hours.ago
    end

    let(:voter_list){ create(:voter_list) }

    before do
      setup_voters(10, {voter_list_id: voter_list.id})
      @query = Voter.remaining_voters_for_voter_list(voter_list)
    end

    context 'no voters in the list have been called' do
      it 'returns the size of the voter list' do
        expect(@query.count).to eq 10
      end
    end

    context '3 voters in the list were called but the call failed' do
      before do
        3.times do |i|
          @voters[i].update_attribute(:status, 'Call failed')
        end
      end
      it 'returns the size of the voter list minus 3' do
        expect(@query.count).to eq 7
      end
    end

    context 'Of 10 voters 1 is in progress, 2 need called back, 5 have not been called and 2 have completed calls' do
      it 'returns the size of the voter list minus the 2 completed calls' do
        @voters.first.update_attribute(:status, CallAttempt::Status::NOANSWER)
        @voters[1..2].each{|v| v.update_attributes(status: CallAttempt::Status::VOICEMAIL, call_back: true)}
        @voters[3..4].each{|v| v.update_attribute(:status, CallAttempt::Status::SUCCESS)}
        expect(@query.count).to eq 8
      end
    end

    context '2 voters in the list have phone numbers that exist on the blocked list' do
      before do
        @voters[0].update_attributes!(enabled: [:list, :blocked])
        @voters[1].update_attributes!(enabled: [:list, :blocked])
        @query = Voter.remaining_voters_for_voter_list(voter_list)
      end

      it 'returns the size of the voter list minus 2' do
        expect(@voters.first.campaign.account.id).not_to be_nil
        expect(@query.count).to eq 8
      end
    end
  end

  describe "Dialing" do
    let(:campaign) { create(:robo) }
    let(:voter) { create(:voter, :campaign => campaign) }

    it "records users to call back" do
      voter1 = create(:voter)
      expect(Voter.to_callback).to eq([])
      voter2 = create(:voter, :call_back =>true)
      expect(Voter.to_callback).to eq([voter2])
    end
  end

  describe "to be dialed" do
    it "includes voters never called" do
      voter = create(:voter, :status => Voter::Status::NOTCALLED)
      expect(Voter.to_be_dialed).to include(voter)
    end

    it "includes voters with a busy signal" do
      voter = create(:voter, :status => CallAttempt::Status::BUSY)
      create(:call_attempt, :voter => voter, :status => CallAttempt::Status::BUSY)
      expect(Voter.to_be_dialed).to include(voter)
    end

    (CallAttempt::Status::ALL - [CallAttempt::Status::INPROGRESS, CallAttempt::Status::RINGING, CallAttempt::Status::READY, CallAttempt::Status::SUCCESS, CallAttempt::Status::FAILED]).each do |status|
      it "includes voters with a status of #{status} " do
        voter = create(:voter, :status => status)
        expect(Voter.to_be_dialed).to include(voter)
      end
    end

    it "excludes voters with a status of a successful call" do
      voter = create(:voter, :status => CallAttempt::Status::SUCCESS)
      expect(Voter.to_be_dialed).not_to include(voter)
    end

    it "is ordered by the last_call_attempt_time" do
      v1 = create(:voter, :status => CallAttempt::Status::BUSY, :last_call_attempt_time => 2.hours.ago)
      v2 = create(:voter, :status => CallAttempt::Status::BUSY, :last_call_attempt_time => 1.hour.ago)
      expect(Voter.to_be_dialed).to include(v1)
      expect(Voter.to_be_dialed).to include(v2)
    end

    it "prioritizes uncalled voters over called voters" do
      called_voter = create(:voter, :status => CallAttempt::Status::BUSY, :last_call_attempt_time => 2.hours.ago)
      uncalled_voter = create(:voter, :status => Voter::Status::NOTCALLED)
      expect(Voter.to_be_dialed).to include(uncalled_voter)
      expect(Voter.to_be_dialed).to include(called_voter)
    end
  end

  describe 'answers' do
    let(:script) { create(:script) }
    let(:campaign) { create(:predictive, :script => script) }
    let(:voter) { create(:voter, :campaign => campaign, :caller_session => create(:caller_session, :caller => create(:caller))) }
    let(:question) { create(:question, :script => script) }
    let(:response) { create(:possible_response, :question => question) }
    let(:call_attempt) { create(:call_attempt, :caller => create(:caller)) }

    it "captures call responses" do
      voter.persist_answers("{\"#{question.id}\":\"#{response.id}\"}",call_attempt)
      expect(voter.answers.size).to eq(1)
    end

    it "puts voter back in the dial list if a retry response is detected" do
      another_response = create(:possible_response, :question => create(:question, :script => script), :retry => true)
      voter.persist_answers("{\"#{question.id}\":\"#{response.id}\",\"#{another_response.question.id}\":\"#{another_response.id}\" }", call_attempt)
      expect(voter.answers.size).to eq(2)
      expect(voter.reload.status).to eq(Voter::Status::RETRY)
      expect(Voter.to_be_dialed).to include(voter)
    end

    it "does not override old responses with newer ones" do
      question = create(:question, :script => script)
      retry_response = create(:possible_response, :question => question, :retry => true)
      valid_response = create(:possible_response, :question => question)
      voter.persist_answers("{\"#{response.question.id}\":\"#{response.id}\",\"#{retry_response.question.id}\":\"#{retry_response.id}\" }",call_attempt)
      expect(voter.answers.size).to eq(2)
      expect(voter.reload.status).to eq(Voter::Status::RETRY)
      expect(Voter.to_be_dialed).to include(voter)
      voter.persist_answers("{\"#{response.question.id}\":\"#{response.id}\",\"#{valid_response.question.id}\":\"#{valid_response.id}\" }",call_attempt)
      expect(voter.reload.answers.size).to eq(4)
    end

    it "returns all questions unanswered" do
      answered_question = create(:question, :script => script)
      create(:answer, :voter => voter, :question => answered_question, :possible_response => create(:possible_response, :question => answered_question))
      pending_question = create(:question, :script => script)
      expect(voter.unanswered_questions).to eq([pending_question])
    end
  end

  describe "notes" do
    let(:script) { create(:script) }
    let(:note1) { create(:note, note: "Question1", script: script) }
    let(:note2) { create(:note, note: "Question2", script: script) }
    let(:call_attempt) { create(:call_attempt, :caller => create(:caller)) }
    let(:voter) { create(:voter, last_call_attempt: call_attempt) }

    it "captures call notes" do
      voter.persist_notes("{\"#{note1.id}\":\"tell\",\"#{note2.id}\":\"no\"}", call_attempt)
      expect(voter.note_responses.size).to eq(2)
    end
  end

  describe "last_call_attempt_before_recycle_rate" do
    it "should return voter if call attempt was before recycle rate hours" do
      campaign = create(:campaign)
      voter = create(:voter, :campaign => campaign, last_call_attempt_time: 150.minutes.ago)
      expect(Voter.last_call_attempt_before_recycle_rate(2)).to include(voter)
    end

    it "should return not voter if call attempt was within recycle rate hours" do
      campaign = create(:campaign)
      voter = create(:voter, :campaign => campaign, last_call_attempt_time: 110.minutes.ago)
      expect(Voter.last_call_attempt_before_recycle_rate(2)).not_to include(voter)
    end

    it "should return  voter if call not attempted " do
      campaign = create(:campaign)
      voter = create(:voter, :campaign => campaign, last_call_attempt_time: nil)
      expect(Voter.last_call_attempt_before_recycle_rate(2)).to include(voter)
    end


  end

  describe "avialable_to_be_retried" do

    it "should not consider voters who have not been dialed" do
      campaign = create(:campaign)
      voter = create(:voter, :campaign => campaign, last_call_attempt_time: nil)
      expect(Voter.avialable_to_be_retried(campaign.recycle_rate)).to eq([])
    end

    it "should not consider voters who last call attempt is within recycle rate" do
      campaign = create(:campaign, recycle_rate: 4)
      voter = create(:voter, :campaign => campaign, last_call_attempt_time: Time.now - 2.hours)
      expect(Voter.avialable_to_be_retried(campaign.recycle_rate)).to eq([])
    end

    it "should  consider voters who last call attempt is not within recycle rate for hangup status" do
      campaign = create(:campaign, recycle_rate: 1)
      voter = create(:voter, :campaign => campaign, last_call_attempt_time: Time.now - 2.hours, status: CallAttempt::Status::HANGUP)
      expect(Voter.avialable_to_be_retried(campaign.recycle_rate)).to include(voter)
    end

    it "should not  consider voters who last call attempt is not within recycle rate for success status" do
      campaign = create(:campaign, recycle_rate: 1)
      voter = create(:voter, :campaign => campaign, last_call_attempt_time: Time.now - 2.hours, status: CallAttempt::Status::SUCCESS)
      expect(Voter.avialable_to_be_retried(campaign.recycle_rate)).not_to include(voter)
    end

  end

  describe "not_avialable_to_be_retried" do

    it "should not consider voters who have not been dialed" do
      campaign = create(:campaign)
      voter = create(:voter, :campaign => campaign, last_call_attempt_time: nil)
      expect(Voter.not_avialable_to_be_retried(campaign.recycle_rate)).to eq([])
    end

    it "should not consider voters who last call attempt is not within recycle rate" do
      campaign = create(:campaign, recycle_rate: 1)
      voter = create(:voter, :campaign => campaign, last_call_attempt_time: Time.now - 2.hours)
      expect(Voter.not_avialable_to_be_retried(campaign.recycle_rate)).to eq([])
    end

    it "should  not consider voters who last call attempt is  within recycle rate for hangup status" do
      campaign = create(:campaign, recycle_rate: 1)
      voter = create(:voter, :campaign => campaign, last_call_attempt_time: Time.now - 2.hours, status: CallAttempt::Status::HANGUP)
      expect(Voter.not_avialable_to_be_retried(campaign.recycle_rate)).to eq([])
    end

    it "should consider voters who last call attempt is not within recycle rate for hangup status" do
      campaign = create(:campaign, recycle_rate: 3)
      voter = create(:voter, :campaign => campaign, last_call_attempt_time: Time.now - 2.hours, status: CallAttempt::Status::HANGUP)
      expect(Voter.not_avialable_to_be_retried(campaign.recycle_rate)).to eq([voter])
    end
  end

  describe '.not_dialed' do
    it 'returns Voters w/ last_call_attempt_time of NULL' do
      create(:voter, :not_recently_dialed, status: Voter::Status::SKIPPED) # dialed then skipped
      create(:voter) # not dialed
      create(:voter, :skipped) # not dialed and skipped
      create(:voter, :abandoned, :not_recently_dialed) # dialed and abandoned

      not_dialed = Voter.not_dialed
      actual     = not_dialed.count

      expect(actual).to(eq(2), [
        "Statuses: #{not_dialed.map(&:status).to_sentence}",
        "Last Call Attempt: #{not_dialed.map(&:last_call_attempt_time).to_sentence}"
      ].join("\n"))
    end
  end

  describe 'retry availability' do
    include FakeCallData

    describe '.not_available_for_retry(campaign)' do
      before(:all) do
        admin     = create(:user)
        account   = admin.account
        @campaign = create_campaign_with_script(:bare_power, account).last

        add_voters(@campaign, :ringing_voter, 10)
        add_voters(@campaign, :queued_voter, 2)
        add_voters(@campaign, :in_progress_voter, 3)
        create_list(:failed_voter, 5, :not_recently_dialed)
        create_list(:voter, 10, :not_recently_dialed, :disabled)
        create_list(:voter, 10, :not_recently_dialed, :deleted)
        create_list(:voter, 10, :recently_dialed, :busy)
        add_voters(@campaign, :voter, 25)

        @voters = Voter.not_available_for_retry(@campaign)
      end

      after(:all) do
        Voter.destroy_all
      end

      context 'includes' do
        it 'within recycle rate threshold' do
          expect(@voters.where(status: CallAttempt::Status::BUSY).count).to eq 10
        end
        it 'ringing' do
          expected = Voter.where(status: CallAttempt::Status::RINGING).count
          actual = @voters.where(status: CallAttempt::Status::RINGING).count

          expect(actual).to eq expected
        end
        it 'in dial queue' do
          expected = Voter.where(status: CallAttempt::Status::READY).count
          actual = @voters.where(status: CallAttempt::Status::READY).count

          expect(actual).to eq expected
        end
        it 'completed' do
          expected = Voter.where(status: CallAttempt::Status::SUCCESS).count
          actual = @voters.where(status: CallAttempt::Status::SUCCESS).count

          expect(actual).to eq expected
        end
        it 'failed' do
          expected = Voter.where(status: CallAttempt::Status::FAILED).count
          actual = @voters.where(status: CallAttempt::Status::FAILED).count

          expect(actual).to eq expected
        end
      end

      context 'does not include' do
        it 'not called unless the not called voter is deleted or inactive' do
          not_called = @voters.where(status: Voter::Status::NOTCALLED)

          not_called.each do |voter|
            expect(voter.active && voter.enabled).to be_falsey
          end
        end
      end
    end

    describe '.available_for_retry(campaign)' do
      context 'past recycle rate' do
        before(:all) do
          admin     = create(:user)
          account   = admin.account
          @campaign = create_campaign_with_script(:bare_power, account, {
            call_back_after_voicemail_delivery: true,
            caller_can_drop_message_manually: true
          }).last

          add_voters(@campaign, :ringing_voter, 10)
          add_voters(@campaign, :queued_voter, 2)
          add_voters(@campaign, :in_progress_voter, 3)
          create_list(:failed_voter, 5, :not_recently_dialed)
          create_list(:voter, 10, :not_recently_dialed, :disabled)
          create_list(:voter, 10, :not_recently_dialed, :deleted)
          create_list(:voter, 10, :not_recently_dialed, :busy)
          create_list(:voter, 10, :not_recently_dialed, :abandoned)
          create_list(:voter, 10, :not_recently_dialed, :no_answer)
          create_list(:voter, 10, :not_recently_dialed, :hangup)
          create_list(:voter, 10, :not_recently_dialed, :voicemail)
          create_list(:voter, 10, :not_recently_dialed, :call_back)
          create_list(:voter, 10, :recently_dialed, :call_back)
          create_list(:voter, 10, :skipped)
          add_voters(@campaign, :voter, 25)
          
          @voters = Voter.available_for_retry(@campaign)
        end

        after(:all) do
          Voter.destroy_all
        end

        let(:expected){ 10 }

        it 'busy' do
          actual   = @voters.where(status: CallAttempt::Status::BUSY).count

          expect(actual).to eq expected
        end
        it 'abandoned' do
          actual   = @voters.where(status: CallAttempt::Status::ABANDONED).count

          expect(actual).to eq expected
        end
        it 'no answer' do
          actual   = @voters.where(status: CallAttempt::Status::NOANSWER).count

          expect(actual).to eq expected
        end
        it 'hangup' do 
          actual   = @voters.where(status: CallAttempt::Status::HANGUP).count

          expect(actual).to eq expected
        end
        it 'voicemail (when campaign set to call back after voicemail delivery)' do
          actual   = @voters.where(status: CallAttempt::Status::VOICEMAIL).count

          expect(actual).to eq expected
        end
        it 'call back' do
          actual   = @voters.where(call_back: true).count

          expect(actual).to eq expected
        end
        it 'skipped' do
          actual = @voters.where(status: Voter::Status::SKIPPED).count

          expect(actual).to eq 10
        end
      end
    end
  end

  describe '.next_in_priority_or_scheduled_queues(blocked_numbers)' do
    let(:campaign){ create(:campaign) }

    xit 'loads voters w/ priority=1 and status=Voter::Status::NOTCALLED' do
      expected = [create(:voter, campaign: campaign, status: Voter::Status::NOTCALLED, priority: true)]
      create(:voter, campaign: campaign, status: nil, priority: true)
      create(:voter, campaign: campaign, status: Voter::Status::RETRY, priority: true)
      actual = Voter.next_in_priority_or_scheduled_queues([])
      expect(actual.all).to eq expected
    end

    xit 'OR voters scheduled to be called back in the last or next 10 minutes' do
      expected = [
        create(:voter, campaign: campaign, status: CallAttempt::Status::SCHEDULED, scheduled_date: 5.minutes.ago),
        create(:voter, campaign: campaign, status: CallAttempt::Status::SCHEDULED, scheduled_date: 5.minutes.from_now)
      ]
      create(:voter, campaign: campaign, status: CallAttempt::Status::SCHEDULED, scheduled_date: 20.minutes.ago)
      create(:voter, campaign: campaign, status: CallAttempt::Status::SCHEDULED, scheduled_date: 20.minutes.from_now)
      actual = Voter.next_in_priority_or_scheduled_queues([])
      expect(actual.all).to eq expected
    end

    xit 'excludes voters w/ phone numbers in the list of blocked numbers' do
      blocked = ['1234567890', '0987654321']
      expected = [
        create(:voter, {
          campaign: campaign,
          status: Voter::Status::NOTCALLED,
          priority: true
        })
      ]
      create(:voter, {
        campaign: campaign,
        status: Voter::Status::NOTCALLED,
        phone: blocked.first
      })
      create(:voter, {
        campaign: campaign,
        status: Voter::Status::NOTCALLED,
        phone: blocked.second
      })
      actual = Voter.next_in_priority_or_scheduled_queues(blocked).all
      expect(actual).to eq expected
    end
  end

  describe '.generally_available(campaign)' do
    let(:campaign){ create(:power) }
    it 'loads active & enabled records excluding those with status in `not_available_list` AND with phone numbers with matching BlockedNumber records BUT including completed if call_back=true' do
      create(:disabled_voter, {campaign: campaign})
      create(:in_progress_voter, {campaign: campaign})
      create(:ringing_voter, {campaign: campaign})
      create(:queued_voter, {campaign: campaign})
      create(:success_voter, {campaign: campaign})
      create(:failed_voter, {campaign: campaign})
      blocked_voter = create(:voter, :blocked, {campaign: campaign})
      excluded_count = Voter.count

      create(:voter, {campaign: campaign})
      create(:busy_voter, {campaign: campaign})
      create(:abandoned_voter, {campaign: campaign})
      create(:no_answer_voter, {campaign: campaign})
      create(:skipped_voter, {campaign: campaign})
      create(:hangup_voter, {campaign: campaign})
      included_count = Voter.count - excluded_count

      available_count = Voter.where(campaign_id: campaign.id).available_list(campaign).count
      expect(available_count).to eq included_count
    end
  end

  describe '.next_voter(recycle_rate, blocked_numbers, current_voter_id)' do
    def setup_voters(campaign_opts={}, voter_opts={}, count=10)
      @campaign = create(:preview, campaign_opts.merge({
        recycle_rate: 1
      }))
      vopt = voter_opts.merge({
        campaign: @campaign,
        enabled: [:list]
      })
      create_list(:voter, count, vopt)
      expect(Voter.count).to eq count
      @voters = @campaign.all_voters
      last_call_time = 20.hours.ago
      @voters.order('id ASC').each do |v|
        v.update_attribute(:last_call_attempt_time, last_call_time)
        last_call_time += 1.hour
      end
    end

    def skip_voters(voters)
      voters.each{|v| v.update_attributes!(skipped_time: 20.minutes.ago, status: Voter::Status::SKIPPED) }
    end

    def attempt_calls(voters)
      voters.each{|v| v.update_attribute('last_call_attempt_time', @campaign.recycle_rate.hours.ago - 1.minute)}
    end

    def attempt_recent_calls(voters)
      voters.each{|v| v.update_attribute('last_call_attempt_time', 5.minutes.ago)}
    end

    context 'current_voter_id is not present' do
      before do
        setup_voters
      end
      context 'all voters have been skipped' do
        it 'returns the first voter with the oldest last_call_attempt_time' do
          skip_voters @voters
          actual = Voter.next_voter(@voters, 1, [], nil)
          expected = @voters.first
          expect(actual).to eq expected
        end
      end
      context 'one voter has not been skipped' do
        it 'returns the first unskipped voter' do
          skip_voters @voters[0..8]
          @voters[9].update_attributes!(last_call_attempt_time: nil, status: Voter::Status::NOTCALLED)
          expected = @voters[9]
          actual = Voter.next_voter(@voters, 1, [], nil)
          expect(actual).to eq expected
        end
      end
      context 'one voter has not been dialed' do
        it 'returns the first voter that has not been dialed' do
          attempt_calls @voters[0..8]
          expected = @voters[9]
          actual = Voter.next_voter(@voters, 1, [], nil)
          expect(actual).to eq expected
        end
      end
      context 'more than one voter has not been skipped' do
        it 'returns the first unskipped voter' do
          skip_voters @voters[3..7]
          expected = @voters[0]
          actual = Voter.next_voter(@voters, 1, [], nil)
          expect(actual).to eq expected
        end
      end
      context 'more than one voter has not been dialed' do
        it 'returns the first voter that has not been dialed' do
          attempt_calls @voters[3..7]
          expected = @voters[0]
          actual = Voter.next_voter(@voters, 1, [], nil)
          expect(actual).to eq expected
        end

        it 'does not return voters marked READY' do
          attempt_calls @voters[3..7]
          @voters[0].update_attributes!(status: CallAttempt::Status::READY, last_call_attempt_time: nil)
          expected = @voters[1]
          actual = Voter.next_voter(@voters, 1, [], nil)
          expect(actual).to eq expected
        end
      end
    end

    context 'current_voter_id is present' do
      before do
        setup_voters
        @current_voter = @voters[3]
      end
      context 'all voters have been skipped' do
        it 'returns the voter with id > current_voter_id' do
          skip_voters @voters
          expected = @voters[4]
          actual = Voter.next_voter(@voters, 1, [], @current_voter.id)
          expect(actual).to eq expected
        end

        it 'returns the first voter in the list when current_voter_id = MAX(id)' do
          @current_voter = @voters[9]
          skip_voters @voters
          expected = @voters[0]
          actual = Voter.next_voter(@voters, 1, [], @current_voter.id)
          expect(actual).to eq expected
        end
      end
      context 'all voters have been dialed' do
        it 'returns the voter with id > current_voter_id' do
          attempt_calls @voters
          expected = @voters[4]
          actual = Voter.next_voter(@voters, 1, [], @current_voter.id)
          expect(actual).to eq expected
        end

        it 'returns the first voter in the list when current_voter_id = MAX(id)' do
          @current_voter = @voters[9]
          attempt_calls @voters
          expected = @voters[0]
          actual = Voter.next_voter(@voters, 1, [], @current_voter.id)
          expect(actual).to eq expected
        end
      end
      context 'one voter has not been skipped' do
        it 'returns the unskipped voter with id > current_voter_id' do
          skip_voters @voters[0..2]
          skip_voters @voters[4..7]
          skip_voters [@voters[9]]
          @voters[8].update_attributes!(last_call_attempt_time: nil)
          expected = @voters[8]
          actual = Voter.next_voter(@voters, 1, [], @current_voter.id)
          expect(actual).to eq expected
        end
      end
      context 'one voter has not been dialed' do
        it 'returns the voter that has not been dialed with id > current_voter_id' do
          attempt_calls @voters[0..8]
          expected = @voters[9]
          actual = Voter.next_voter(@voters, 1, [], @current_voter.id)
          expect(actual).to eq expected
        end

        it 'returns the voter that has not been dialed when current_voter_id < MAX(id) BUT current_voter_id > NOTCALLED(id)' do
          @current_voter = @voters[8]
          attempt_calls @voters[0..2]
          attempt_calls @voters[4..9]
          @voters[3].update_attributes!(last_call_attempt_time: nil)
          expected = @voters[3]
          actual = Voter.next_voter(@voters, 1, [], @current_voter.id)

          # binding.pry
          expect(actual).to eq expected
        end
      end
      context 'more than one voter has not been skipped' do
        it 'returns the first unskipped voter with id > current_voter_id' do
          skip_voters @voters[0..2]
          skip_voters @voters[5..6]
          expected = @voters[4]
          actual = Voter.next_voter(@voters, 1, [], @current_voter.id)
          expect(actual).to eq expected
        end
      end
      context 'more than one voter has not been dialed' do
        it 'returns the first voter that has not been dialed with id > current_voter_id' do
          attempt_calls @voters[0..2]
          attempt_calls @voters[5..6]
          expected = @voters[4]
          actual = Voter.next_voter(@voters, 1, [], @current_voter.id)
          expect(actual).to eq expected
        end
      end
      context 'all voters have been attempted but none skipped and they are ready to be retried and the voter w/ the largest id was just dialed' do
        it 'returns the first voter not skipped voter' do
          attempt_calls(@voters)
          expected = @voters.first
          actual = Voter.next_voter(@voters, @campaign.recycle_rate, [], @voters.last.id)
          expect(actual).to eq expected
        end
      end
    end
  end
end

# ## Schema Information
#
# Table name: `voters`
#
# ### Columns
#
# Name                          | Type               | Attributes
# ----------------------------- | ------------------ | ---------------------------
# **`id`**                      | `integer`          | `not null, primary key`
# **`phone`**                   | `string(255)`      |
# **`custom_id`**               | `string(255)`      |
# **`last_name`**               | `string(255)`      |
# **`first_name`**              | `string(255)`      |
# **`middle_name`**             | `string(255)`      |
# **`suffix`**                  | `string(255)`      |
# **`email`**                   | `string(255)`      |
# **`result`**                  | `string(255)`      |
# **`caller_session_id`**       | `integer`          |
# **`campaign_id`**             | `integer`          |
# **`account_id`**              | `integer`          |
# **`active`**                  | `boolean`          | `default(TRUE)`
# **`created_at`**              | `datetime`         |
# **`updated_at`**              | `datetime`         |
# **`status`**                  | `string(255)`      | `default("not called")`
# **`voter_list_id`**           | `integer`          |
# **`call_back`**               | `boolean`          | `default(FALSE)`
# **`caller_id`**               | `integer`          |
# **`result_digit`**            | `string(255)`      |
# **`attempt_id`**              | `integer`          |
# **`result_date`**             | `datetime`         |
# **`last_call_attempt_id`**    | `integer`          |
# **`last_call_attempt_time`**  | `datetime`         |
# **`num_family`**              | `integer`          | `default(1)`
# **`family_id_answered`**      | `integer`          |
# **`result_json`**             | `text`             |
# **`scheduled_date`**          | `datetime`         |
# **`address`**                 | `string(255)`      |
# **`city`**                    | `string(255)`      |
# **`state`**                   | `string(255)`      |
# **`zip_code`**                | `string(255)`      |
# **`country`**                 | `string(255)`      |
# **`skipped_time`**            | `datetime`         |
# **`priority`**                | `string(255)`      |
# **`lock_version`**            | `integer`          | `default(0)`
# **`enabled`**                 | `integer`          | `default(0), not null`
# **`voicemail_history`**       | `string(255)`      |
# **`household_id`**            | `integer`          |
#
# ### Indexes
#
# * `index_priority_voters`:
#     * **`campaign_id`**
#     * **`enabled`**
#     * **`priority`**
#     * **`status`**
# * `index_voters_caller_id_campaign_id`:
#     * **`caller_id`**
#     * **`campaign_id`**
# * `index_voters_customid_campaign_id`:
#     * **`custom_id`**
#     * **`campaign_id`**
# * `index_voters_on_Phone_and_voter_list_id`:
#     * **`phone`**
#     * **`voter_list_id`**
# * `index_voters_on_attempt_id`:
#     * **`attempt_id`**
# * `index_voters_on_caller_session_id`:
#     * **`caller_session_id`**
# * `index_voters_on_campaign_id_and_active_and_status_and_call_back`:
#     * **`campaign_id`**
#     * **`active`**
#     * **`status`**
#     * **`call_back`**
# * `index_voters_on_campaign_id_and_status_and_id`:
#     * **`campaign_id`**
#     * **`status`**
#     * **`id`**
# * `index_voters_on_household_id`:
#     * **`household_id`**
# * `index_voters_on_status`:
#     * **`status`**
# * `index_voters_on_voter_list_id`:
#     * **`voter_list_id`**
# * `report_query`:
#     * **`campaign_id`**
#     * **`id`**
# * `voters_campaign_status_time`:
#     * **`campaign_id`**
#     * **`status`**
#     * **`last_call_attempt_time`**
# * `voters_enabled_campaign_time_status`:
#     * **`enabled`**
#     * **`campaign_id`**
#     * **`last_call_attempt_time`**
#     * **`status`**
#
