ssh_options[:user] = "impactdialing"
ssh_options[:keys] = ["config/deploy/ssh-keys/app-aws.pem"]

server 'ec2-50-19-174-132.compute-1.amazonaws.com', :app, :web    #app3
server 'ec2-54-242-82-13.compute-1.amazonaws.com', :app, :web     #app4
server 'ec2-184-73-108-160.compute-1.amazonaws.com', :app, :web   #app5
server 'ec2-23-21-18-102.compute-1.amazonaws.com', :app, :web     #app6
server 'ec2-174-129-154-129.compute-1.amazonaws.com', :app, :web  #app7