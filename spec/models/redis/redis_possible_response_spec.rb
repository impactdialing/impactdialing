require "spec_helper"

describe RedisPossibleResponse, :type => :model do
  let(:possible_responses) do
    [
      double('PossibleResponse', {id: 1, keypad: 1, value: 'test'}),
      double('PossibleResponse', {id: 1, keypad: 2, value: 'test1'}),
      double('PossibleResponse', {id: 1, keypad: 2, value: 'test2'})
    ]
  end
  it "should give possible responses for a question" do
    possible_responses.each do |possible_response|
      RedisPossibleResponse.persist_possible_response(1, possible_response)
    end
    
    expect(RedisPossibleResponse.possible_responses(1)).to eq([{"id"=>1, "keypad"=>2, "value"=>"test2"}, {"id"=>1, "keypad"=>2, "value"=>"test1"}, {"id"=>1, "keypad"=>1, "value"=>"test"}])
  end
end