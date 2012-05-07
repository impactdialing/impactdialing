# require "spec_helper"
# 
# describe ApplicationController do
#   it "redirects to the https version of broadcast" do
#     controller.stub(:testing?).and_return(false)
#     request.stub(:domain).and_return('some_domain')
#     request.stub(:path).and_return('/some_path')
#     request.env['HTTPS'] = 'off'
#     controller.stub(:controller_name).and_return('broadcast')
#     controller.should_receive(:redirect_to).with('https://broadcast.some_domain/some_path')
#     controller.redirect_to_ssl.should_not be
#   end
# 
#   ['staging', 'preprod'].each do |env|
#     it "redirects to the https version of broadcast in #{env}" do
#       controller.stub(:testing?).and_return(false)
#       request.stub(:subdomain).and_return(env)
#       request.stub(:domain).and_return('somedomain.com')
#       request.stub(:path).and_return('/some_path')
#       request.env['HTTPS'] = 'off'
#       controller.should_receive(:redirect_to).with("https://#{env}.somedomain.com/some_path")
#       controller.redirect_to_ssl.should_not be
#     end
#   end
# end
