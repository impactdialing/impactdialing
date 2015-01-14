require 'spec_helper'

describe 'PersistPhonesOnlyAnswers' do
  include FakeCallData

  let(:redis){ Redis.new }
  let(:iteration_count){ 10 }
  let(:account){ create(:account) }
  let(:script_questions_campaign) do
    # creates questions & possible responses too
    create_campaign_with_script(:power, account)
  end
  let(:campaign){ script_questions_campaign.last }
  let(:questions){ script_questions_campaign[1] }
  let(:callers){ create_list(:caller, 3, is_phones_only: true, campaign: campaign, account: account) }
  let(:caller_sessions) do
    [callers.sample, callers.sample].map do |caller|
      create(:phones_only_caller_session, campaign: campaign, caller: caller)
    end
  end
  let(:voters){ create_list(:voter, iteration_count, campaign: campaign, account: account) }

  before do
    redis.flushall
  end

  def create_voter_and_call
    voter          = create(:voter, campaign: campaign, account: account)
    caller_session = caller_sessions.sample
    call_attempt   = voter.household.call_attempts.create({
      campaign: campaign,
      dialer_mode: campaign.type,
      call_start: Time.now
    })
    Call.create(call_attempt: call_attempt, state: 'initial')
    caller_session.update_attributes({
      attempt_in_progress: call_attempt
    })

    return [voter, caller_session]
  end

  context 'a PossibleResponse#retry is true' do
    before do
      possible_response = questions.first.possible_responses.sample
      possible_response.update_attributes!({:retry => true})

      voter, caller_session = create_voter_and_call
      @retry_voter          = voter
      question              = questions.first
      digit                 = question.possible_responses.where(:retry => true).sample.keypad
      RedisPhonesOnlyAnswer.push_to_list(voter.id, voter.household.id, caller_session.id, digit, question.id)

      (iteration_count - 1).times do
        voter, caller_session = create_voter_and_call

        questions[1..-1].each do |question|
          digit = question.possible_responses.where(:retry => false).sample.keypad
          RedisPhonesOnlyAnswer.push_to_list(voter.id, voter.household.id, caller_session.id, digit, question.id)
        end
      end

      PersistPhonesOnlyAnswers.perform
    end

    it 'sets Voter#call_back to true' do
      expect(@retry_voter.reload.call_back).to be_truthy
      expect(Voter.where('id <> ?', @retry_voter.id).where(call_back: true).count).to be_zero
    end

    it 'sets Voter#status to Voter::Status::RETRY' do
      expect(@retry_voter.reload.status).to eq Voter::Status::RETRY
      expect(Voter.where('id <> ?', @retry_voter.id).where(status: Voter::Status::RETRY).count).to be_zero
    end
  end

  context 'some items are on the list and all define a valid voter_id, caller_session_id, question_id & digit' do
    before do
      iteration_count.times do
        voter, caller_session = create_voter_and_call

        questions.each do |question|
          digit = question.possible_responses.sample.keypad
          RedisPhonesOnlyAnswer.push_to_list(voter.id, voter.household.id, caller_session.id, digit, question.id)
        end
      end
    end

    it 'creates an Answer record for every item' do
      expected = iteration_count * Question.count

      expect{
        PersistPhonesOnlyAnswers.perform
      }.to change{
        Answer.count
      }.from(0).to(expected)
    end

    context 'each Answer record is associated with' do
      before do
        PersistPhonesOnlyAnswers.perform
      end

      [
        'voter_id', 'caller_id', 'call_attempt_id',
        'campaign_id', 'question_id', 'possible_response_id'
      ].each do |column|
        it "#{column}" do
          expected = iteration_count * Question.count
          expect(Answer.where("#{column} IS NOT NULL").count).to eq expected
        end
      end
    end
  end

  shared_examples 'all partial items' do
    it 'moves the partial items from the pending list to the partial list' do
      PersistPhonesOnlyAnswers.perform
      partial_items        = redis.lrange(RedisPhonesOnlyAnswer.keys[:partial], 0, -1)
      partial_question_ids = partial_items.map do |item|
        JSON.parse(item)['question_id']
      end

      expect(partial_question_ids).to eq questions[0..-2].map(&:id)
    end
  end

  context 'when an item is missing some data' do
    before do
      voter, caller_session = create_voter_and_call

      questions[0..-2].each do |question|
        digit = question.possible_responses.sample.keypad
        RedisPhonesOnlyAnswer.push_to_list(voter.id, voter.household.id, nil, digit, question.id)
      end
      digit = questions.last.possible_responses.sample.keypad
      RedisPhonesOnlyAnswer.push_to_list(voter.id, voter.household.id, caller_sessions.sample.id, digit, questions.last.id)
    end
  end

  context 'when an item is missing a possible response for the given digit (keypad)' do
    before do
      voter, caller_session = create_voter_and_call

      questions[0..-2].each do |question|
        RedisPhonesOnlyAnswer.push_to_list(voter.id, voter.household.id, caller_session.id, 1234567890, question.id)
      end
      digit = questions.last.possible_responses.sample.keypad
      RedisPhonesOnlyAnswer.push_to_list(voter.id, voter.household.id, caller_sessions.sample.id, digit, questions.last.id)
    end

    it_behaves_like 'all partial items'
  end

  context 'any Exception is raised' do
    before do
      @voter, @caller_session = create_voter_and_call

      questions[0..-2].each do |question|
        @digit ||= digit = question.possible_responses.sample.keypad
        RedisPhonesOnlyAnswer.push_to_list(@voter.id, @voter.household.id, @caller_session.id, digit, question.id)
      end
      digit = questions.last.possible_responses.sample.keypad
      RedisPhonesOnlyAnswer.push_to_list(@voter.id, @voter.household.id, caller_sessions.sample.id, digit, questions.last.id)
    end

    it 'leaves data on the pending list' do
      allow(@voter).to receive_message_chain(:household, :last_call_attempt, :id){ raise NoMethodError }
      allow(Voter).to receive(:find){ @voter }
      begin
        PersistPhonesOnlyAnswers.perform
      rescue NoMethodError
      end
      pending_items = redis.lrange(RedisPhonesOnlyAnswer.keys[:pending], 0, -1)
      item = JSON.parse(pending_items.first)
      expected_item = {
        'voter_id' => @voter.id,
        'household_id' => @voter.household_id,
        'caller_session_id' => @caller_session.id,
        'question_id' => questions.first.id,
        'digit' => @digit
      }
      expect(item).to eq expected_item
    end
  end
end
