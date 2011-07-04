class TwilioController < ApplicationController
  include ::Twilio
  def callback
    verb = Twilio::Verb.new { |v|
      v.play "http://s3.amazonaws.com/impactdiallingapp/BachGavotteShort.mp3"
      v.say "The time is #{Time.now}"
      v.hangup
    }
    render :xml => verb.response
    response.headers["Content-Type"] = 'text/xml'
  end

  def report_error
    puts "Error", params.inspect
    render :text => ''
  end

  def call_ended
    puts "Call Ended", params
    render :text => ''
  end
end
