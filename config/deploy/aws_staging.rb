ssh_options[:user] = "impactdialing"
ssh_options[:keys] = ["config/deploy/ssh-keys/app-aws-staging.pem"]

[:web, :app, :db].each do |role_name|
  role role_name, 'ec2-23-20-57-112.compute-1.amazonaws.com', :primary => true
end
