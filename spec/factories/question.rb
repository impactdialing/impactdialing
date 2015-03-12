FactoryGirl.define do
  factory :bare_question, class: 'Question' do
    text { Forgery(:lorem_ipsum).sentence }
    script_order { generate(:order) }
  end
end
