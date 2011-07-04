class TwilioController < ApplicationController
  def callback
    render :xml => Twilio::Verb.play(URI.escape('http://impactdialingapp.s3.amazonaws.com/development/uploads/1/6MontyPython.wav'))
  end

  def report_error
    puts "Error", params
    render :text => ''
  end

  def call_ended
    puts "Call Ended", params
    render :text => ''
  end
end
