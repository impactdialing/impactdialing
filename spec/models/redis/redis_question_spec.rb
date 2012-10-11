require "spec_helper"

describe RedisQuestion do
  
  it "should persist question" do
    RedisQuestion.persist_questions(1, 1, "Hello")
    RedisQuestion.get_question_to_read(1, 0)["question_text"].should eq("Hello")
  end
end