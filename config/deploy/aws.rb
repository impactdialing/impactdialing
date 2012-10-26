ssh_options[:user] = "impactdialing"
ssh_options[:keys] = ["config/deploy/ssh-keys/app-aws-staging.pem"]


server "ec2-107-22-30-120.compute-1.amazonaws.com", :app, :web, :db, :primary => true
server "ec2-184-73-125-26.compute-1.amazonaws.com", :app, :web 
