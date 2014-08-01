FactoryGirl.define do
  factory :bare_answer, class: 'Answer' do
    # all associations, sans (updated|created)_at fields
  end
end