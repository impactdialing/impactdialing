FactoryGirl.define do
  sequence :possible_response_order do |n|
    n + 1
  end

  sequence :keypad do |n|
    n
  end

  factory :bare_possible_response, class: 'PossibleResponse' do
    value { Forgery(:basic).text }
    possible_response_order { generate(:possible_response_order) }
    keypad { generate(:keypad) }
  end
end
