FactoryGirl.define do  
  factory :bare_script, class: 'Script' do
    name { Forgery(:basic).text }
  end
end
