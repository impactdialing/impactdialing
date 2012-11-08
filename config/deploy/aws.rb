ssh_options[:user] = "impactdialing"
ssh_options[:keys] = ["config/deploy/ssh-keys/app-aws.pem"]

server 'ec2-54-242-125-140.compute-1.amazonaws.com', :app, :web #LTS1
server 'ec2-23-22-88-46.compute-1.amazonaws.com',    :app, :web #LTS2
