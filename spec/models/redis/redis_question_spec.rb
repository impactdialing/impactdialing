require "spec_helper"

describe RedisQuestion do
  
  it "should persist question" do
    RedisQuestion.persist_questions(1, 1, "Hello")
    RedisQuestion.get_question_to_read(1, 0)["question_text"].should eq("Hello")
  end
  
  it "should reutrn true if moe questions are to be answered" do
    RedisQuestion.persist_questions(1, 1, "Hello")
    RedisQuestion.persist_questions(1, 2, "Kitty")
    RedisQuestion.persist_questions(1, 3, "Welcome")
    RedisQuestion.more_questions_to_be_answered?(1, "2").should be_true
    RedisQuestion.more_questions_to_be_answered?(1, "3").should be_false
  end
end