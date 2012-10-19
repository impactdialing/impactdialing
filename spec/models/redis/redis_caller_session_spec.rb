require "spec_helper"

describe RedisCallerSession do
  
  it "should set options" do
    RedisCallerSession.set_request_params(1, {digit: 1, question_number: 2, question_id: 3})
    result = RedisCallerSession.get_request_params(1)
    JSON.parse(result).should eq({"digit"=>1, "question_number"=>2, "question_id"=>3})
  end
  
  it "should get digit" do
    RedisCallerSession.set_request_params(1, {digit: 1, question_number: 2, question_id: 3})
    RedisCallerSession.digit(1).should eq(1)
  end
  
  it "should get question number" do
    RedisCallerSession.set_request_params(1, {digit: 1, question_number: 2, question_id: 3})
    RedisCallerSession.question_number(1).should eq(2)
  end
  
  it "should get question id" do
    RedisCallerSession.set_request_params(1, {digit: 1, question_number: 2, question_id: 3})
    RedisCallerSession.question_id(1).should eq(3)
  end
  
  
end