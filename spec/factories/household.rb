FactoryGirl.define do
  factory :household, class: 'Household' do
    account
    campaign
    voter_list
    phone { Forgery(:address).phone }
    enabled [:list]
  end
end