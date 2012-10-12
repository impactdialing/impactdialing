require "spec_helper"

describe RedisPossibleResponse do
  
  
  it "should give possible responses for a question" do
    RedisPossibleResponse.persist_possible_response(1, 1, "test")
    RedisPossibleResponse.persist_possible_response(1, 2, "test1")
    RedisPossibleResponse.persist_possible_response(1, 2, "test2")
    RedisPossibleResponse.possible_responses(1).should eq([{"id"=>1, "keypad"=>2, "value"=>"test2"}, {"id"=>1, "keypad"=>2, "value"=>"test1"}, {"id"=>1, "keypad"=>1, "value"=>"test"}])
  end
end