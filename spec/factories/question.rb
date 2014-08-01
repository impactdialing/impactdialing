FactoryGirl.define do
  sequence :script_order do |n|
    n + 1
  end

  factory :bare_question, class: 'Question' do
    text { Forgery(:basic).text }
    script_order { generate(:script_order) }
  end
end
