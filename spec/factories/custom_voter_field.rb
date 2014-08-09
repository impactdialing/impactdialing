FactoryGirl.define do
  factory :bare_custom_voter_field, class: 'CustomVoterField' do
    name { Forgery(:name).company_name }
  end
end