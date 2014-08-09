FactoryGirl.define do
  factory :bare_voter, class: 'Voter' do
    first_name { Forgery(:name).first_name }
    phone { Forgery(:address).phone }
    updated_at Time.now

    factory :realistic_voter do
      last_name { Forgery(:name).last_name }
      email { Forgery(:email).address }
      address { Forgery(:address).street_address }
      city { Forgery(:address).city }
      state { Forgery(:address).state }
      zip_code { Forgery(:address).zip }
      country { Forgery(:address).country }
    end
  end
end