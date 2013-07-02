require "integration_spec_helper"
require "twilio_helper"
require "twilio_proxy"


describe "WebuiPreview" do
  include TwilioHelper
  before(:each) do
    @twilio_proxy = TwilioProxy.new
    @conn = Faraday.new(:url => 'http://localhost:3000')
  end

end
