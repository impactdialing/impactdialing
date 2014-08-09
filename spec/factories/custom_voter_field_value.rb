FactoryGirl.define do
  factory :bare_custom_voter_field_value, class: 'CustomVoterFieldValue' do
    value { Forgery(:basic).text }
  end
end