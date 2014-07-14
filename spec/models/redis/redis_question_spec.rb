require "spec_helper"

describe RedisQuestion, :type => :model do

  it "should persist question" do
    RedisQuestion.persist_questions(1, 1, "Hello")
    expect(RedisQuestion.get_question_to_read(1, 0)["question_text"]).to eq("Hello")
  end

  it "should reutrn true if moe questions are to be answered" do
    RedisQuestion.persist_questions(1, 1, "Hello")
    RedisQuestion.persist_questions(1, 2, "Kitty")
    RedisQuestion.persist_questions(1, 3, "Welcome")
    expect(RedisQuestion.more_questions_to_be_answered?(1, 2)).to be_truthy
    expect(RedisQuestion.more_questions_to_be_answered?(1, 3)).to be_falsey
  end
end