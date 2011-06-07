Factory.sequence :email do |n|
  "user#{n}@example.com"
end

Factory.define :user do |u|
  u.email { Factory.next(:email) }
  u.password 'password'
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
