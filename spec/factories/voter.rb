FactoryGirl.define do
  factory :bare_voter, class: 'Voter' do
    first_name { Forgery(:name).first_name }
    phone { Forgery(:address).phone }
    updated_at Time.now
  end
end