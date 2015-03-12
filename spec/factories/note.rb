FactoryGirl.define do
  factory :bare_note, class: 'Note' do
    script_order { generate(:order) }
    note { Forgery(:lorem_ipsum).sentence }
  end
end
