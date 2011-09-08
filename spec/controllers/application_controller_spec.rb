require "spec_helper"

describe ApplicationController do
  it "redirects to the https version of broadcast" do
    controller.stub(:testing?).and_return(false)
    request.stub(:domain).and_return('some_domain')
    request.stub(:path).and_return('/some_path')
    request.env['HTTPS'] = 'off'
    controller.stub(:controller_name).and_return('broadcast')
    controller.should_receive(:redirect_to).with('https://broadcast.some_domain/some_path')
    controller.redirect_to_ssl.should_not be
  end
end
