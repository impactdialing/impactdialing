require 'rails_helper'

describe RedisCallerSession, :type => :model do
  subject{ RedisCallerSession }

  it "should set options" do
    subject.set_request_params(1, {digit: 1, question_number: 2, question_id: 3})
    result = subject.get_request_params(1)
    expect(JSON.parse(result)).to eq({"digit"=>1, "question_number"=>2, "question_id"=>3})
  end

  it "should get digit" do
    subject.set_request_params(1, {digit: 1, question_number: 2, question_id: 3})
    expect(subject.digit(1)).to eq(1)
  end

  it "should get question number" do
    subject.set_request_params(1, {digit: 1, question_number: 2, question_id: 3})
    expect(subject.question_number(1)).to eq(2)
  end

  it "should get question id" do
    subject.set_request_params(1, {digit: 1, question_number: 2, question_id: 3})
    expect(subject.question_id(1)).to eq(3)
  end
end
