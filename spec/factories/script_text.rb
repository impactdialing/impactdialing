FactoryGirl.define do
  sequence :order do |n|
    n + 1
  end

  factory :bare_script_text, class: 'ScriptText' do
    script_order { generate(:order) }
    content { Forgery(:lorem_ipsum).paragraphs(2) }
  end
end