ssh_options[:user] = "impactdialing"
ssh_options[:keys] = ["config/deploy/ssh-keys/app-aws.pem"]

#server 'ec2-50-19-174-132.compute-1.amazonaws.com',   :app, :web
#server 'ec2-54-242-82-13.compute-1.amazonaws.com',    :app, :web
#server 'ec2-184-73-108-160.compute-1.amazonaws.com',  :app, :web
#server 'ec2-23-21-18-102.compute-1.amazonaws.com',    :app, :web
#server 'ec2-174-129-154-129.compute-1.amazonaws.com', :app, :web
#server 'ec2-50-17-179-238.compute-1.amazonaws.com',   :app, :web
#server 'ec2-50-16-137-110.compute-1.amazonaws.com',   :app, :web
#server 'ec2-23-22-168-37.compute-1.amazonaws.com',    :app, :web
#server 'ec2-75-101-190-60.compute-1.amazonaws.com',   :app, :web

server 'ec2-54-242-120-28.compute-1.amazonaws.com',   :app, :web
server 'ec2-50-17-109-135.compute-1.amazonaws.com',   :app, :web
server 'ec2-54-242-74-168.compute-1.amazonaws.com',   :app, :web
server 'ec2-54-242-82-254.compute-1.amazonaws.com',   :app, :web
server 'ec2-23-20-251-243.compute-1.amazonaws.com',   :app, :web
server 'ec2-23-22-170-104.compute-1.amazonaws.com',   :app, :web
