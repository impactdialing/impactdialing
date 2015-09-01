require 'rails_helper'

describe RedisPossibleResponse, :type => :model do
  let(:possible_responses) do
    [
      double('PossibleResponse', {id: 3, keypad: 1, value: 'test'}),
      double('PossibleResponse', {id: 4, keypad: 2, value: 'test1'}),
      double('PossibleResponse', {id: 5, keypad: 3, value: 'test2'})
    ]
  end
  it "should give possible responses for a question" do
    possible_responses.each do |possible_response|
      RedisPossibleResponse.persist_possible_response(1, possible_response)
    end

    expected = [
      {"id"=>1, "possible_response_id" => 5, "keypad"=>3, "value"=>"test2"},
      {"id"=>1, "possible_response_id" => 4, "keypad"=>2, "value"=>"test1"},
      {"id"=>1, "possible_response_id" => 3, "keypad"=>1, "value"=>"test"}
    ]
    
    expect(RedisPossibleResponse.possible_responses(1)).to eq(expected)
  end
end
