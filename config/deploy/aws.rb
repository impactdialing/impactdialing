ssh_options[:user] = "impactdialing"
ssh_options[:keys] = ["config/deploy/ssh-keys/app-aws.pem"]

server 'ec2-54-242-125-140.compute-1.amazonaws.com', :app, :web #LTS1
server 'ec2-23-22-88-46.compute-1.amazonaws.com',    :app, :web #LTS2
server 'ec2-23-23-58-52.compute-1.amazonaws.com',    :app, :web #LTS3
server 'ec2-54-242-170-12.compute-1.amazonaws.com',  :app, :web #LTS4
server 'ec2-23-22-20-226.compute-1.amazonaws.com',   :app, :web #LTS5
server 'ec2-54-242-176-51.compute-1.amazonaws.com',  :app, :web #LTS6
server 'ec2-107-20-71-30.compute-1.amazonaws.com',   :app, :web #LTS7
server 'ec2-23-22-223-41.compute-1.amazonaws.com',   :app, :web #LTS8
