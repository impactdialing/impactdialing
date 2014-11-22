require "spec_helper"

describe RedisQuestion, :type => :model do
  let(:questions) do
    [
      double('Question', {id: 1, text: 'Hello'}),
      double('Question', {id: 2, text: 'Kitty'}),
      double('Question', {id: 3, text: 'Welcome'})
    ]
  end

  before do
    Redis.new.flushall
  end

  it "should persist question" do
    RedisQuestion.persist_questions(1, questions.first)

    expect(RedisQuestion.get_question_to_read(1, 0)["question_text"]).to eq(questions.first.text)
  end

  it "should reutrn true if moe questions are to be answered" do
    questions.each do |question|
      RedisQuestion.persist_questions(1, question)
    end

    expect(RedisQuestion.more_questions_to_be_answered?(1, 2)).to be_truthy
    expect(RedisQuestion.more_questions_to_be_answered?(1, 3)).to be_falsey
  end
end