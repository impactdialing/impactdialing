Factory.sequence :email do |n|
  "user#{n}@example.com"
end

Factory.sequence :name do |n|
  "user#{n}"
end

Factory.sequence :phonenumber do |n|
  "#{(10**10)+n}"
end


Factory.define :user do |u|
  u.email { Factory.next(:email) }
  u.new_password 'password'
end

Factory.define :campaign do |c|
  c.name 'a campaign'
end

Factory.define :script do |s|
  s.name 'a script'
end

Factory.define :caller do |s|
  s.name 'a caller'
end

Factory.define :voter_list do |v|
  v.campaign_id { Factory(:campaign).id }
  v.name { Factory.next(:name) }
  v.user_id { Factory(:user).id }
end

Factory.define :voter do |v|
  v.FirstName { Factory.next(:name) }
  v.Phone { Factory.next(:phonenumber) }
end

Factory.define :caller_session do |s|
  s.campaign_id { Factory(:campaign, :user => Factory(:user)).id }
  s.caller_id { Factory(:caller)}
end

Factory.define :call_attempt do |ca|
end