require 'spec_helper'

describe 'CachePhonesOnlyScriptQuestions' do
  include FakeCallData

  def update_script(script)
    questions = Question.all

    script.update_attributes!({
      questions_attributes: [
        {
          id: questions[0].id,
          text: "Updated Question #{questions[0].id}",
          possible_responses_attributes: [
            {
              id: questions[0].possible_responses[0].id,
              value: "Updated PossibleResponse #{questions[0].possible_responses[0].id}",
              keypad: 23
            },
            {
              id: questions[0].possible_responses[1].id,
              value: "Updated PossibleResponse #{questions[0].possible_responses[1].id}",
              keypad: 24
            }
          ]
        },
        {
          id: questions[1].id,
          text: "Updated Question #{questions[1].id}",
          possible_responses_attributes: [
            {
              id: questions[1].possible_responses[0].id,
              value: "Updated PossibleResponse #{questions[1].possible_responses[0].id}",
              keypad: 25
            },
            {
              id: questions[1].possible_responses[1].id,
              value: "Updated PossibleResponse #{questions[1].possible_responses[1].id}",
              keypad: 26
            }
          ]
        }
      ]
    })
  end

  before do
    admin   = create(:user)
    account = admin.account
    @script = create_campaign_with_script(:bare_power, account).first
  end

  after do
    RedisQuestion.clear_list(@script.id)
    @script.questions.pluck(:id).each do |question_id|
      RedisPossibleResponse.clear_list(question_id)
    end
  end

  describe '.queue(script_id, action)' do
    it 'can queue itself, whynot?' do
      expect(Resque).to receive(:enqueue).with(CachePhonesOnlyScriptQuestions, 42, 'mice')
      
      CachePhonesOnlyScriptQuestions.queue(42, 'mice')
    end
  end

  describe '.perform(script_id, "seed")' do
    it 'seeds the question & possible response cache if no cache data will be overwritten' do
      qlist_length = CachePhonesOnlyScriptQuestions.redis.llen(RedisQuestion.key(@script.id))
      expect(qlist_length).to be_zero

      CachePhonesOnlyScriptQuestions.perform(@script.id, 'seed')

      qlist_length = RedisQuestion.redis.llen(RedisQuestion.key(@script.id))
      expected     = @script.questions.count
      expect(qlist_length).to(eq(expected), [
        "Expected RedisQuestion to have #{expected} questions cached",
        "Got #{qlist_length}"
      ].join("\n"))

      question = @script.questions.first
      rlist_length = RedisPossibleResponse.redis.llen(RedisPossibleResponse.key(question.id))
      expect(rlist_length).to eq question.possible_responses.count
    end

    it 'does nothing if cache will be overwritten' do
      CachePhonesOnlyScriptQuestions.perform(@script.id, 'seed')

      new_text = 'Updated Question Text that should not appear in cache'
      @script.questions.update_all(text: new_text)

      CachePhonesOnlyScriptQuestions.perform(@script.id, 'seed')

      question = RedisQuestion.get_question_to_read(@script.id, 0)
      expect(question['question_text']).to_not eq new_text
    end

    it 'sets TTL for relevant keys' do
      CachePhonesOnlyScriptQuestions.perform(@script.id, 'seed')

      actual   = RedisQuestion.redis.ttl(RedisQuestion.key(@script.id))
      expected = (5.hours + 59.minutes)

      expect(actual > expected).to be_truthy

      @script.questions.each do |question|
        oops = "Expected key[#{RedisPossibleResponse.key(question.id)}] to have TTL but it did not\n"

        actual = RedisPossibleResponse.redis.ttl(RedisPossibleResponse.key(question.id))

        expect(actual > expected).to(be_truthy, oops)
      end
    end
  end

  describe '.perform(script_id, "update")' do
    context 'questions or possible responses have changed and exist in cache' do
      before do
        CachePhonesOnlyScriptQuestions.perform(@script.id, 'seed')

        update_script(@script)
        CachePhonesOnlyScriptQuestions.perform(@script.id, 'update')
      end

      let(:questions){ Question.all }

      it 'updates questions cache' do
        question = RedisQuestion.get_question_to_read(@script.id, 0)

        expect(question['question_text']).to eq questions[0].text

        question = RedisQuestion.get_question_to_read(@script.id, 1)
        expect(question['question_text']).to eq questions[1].text
      end

      it 'updates possible responses cache' do
        updated_questions = @script.questions[0..1]
        updated_responses = updated_questions.map(&:possible_responses).flatten
        question_ids      = updated_questions.map(&:id)

        cached_responses = RedisPossibleResponse.possible_responses(question_ids.first)
        expect(cached_responses[0]['value']).to eq updated_responses[0].value
        expect(cached_responses[1]['value']).to eq updated_responses[1].value

        cached_responses = RedisPossibleResponse.possible_responses(question_ids.last)
        expect(cached_responses[0]['value']).to eq updated_responses[4].value
        expect(cached_responses[1]['value']).to eq updated_responses[5].value
      end
    end

    context 'neither questions nor possible responses have changed and exist in cache' do
      it 'does not update questions cache'

      it 'does not update possible responses cache'
    end

    context 'questions or possible responses have changed but do not exist in cache' do
      it 'does not populate questions cache (cache is populated at CallinController#identify)'

      it 'does not populate possible responses cache (cache is populated at CallinController#identify)'
    end
  end
end