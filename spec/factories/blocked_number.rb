FactoryGirl.define do
  factory :bare_blocked_number, class: 'BlockedNumber' do
    number{ Forgery(:address).phone }
  end
end