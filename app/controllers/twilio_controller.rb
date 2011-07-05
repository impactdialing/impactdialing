class TwilioController < ApplicationController
  include ::Twilio

  def callback
    call_attempt = Campaign.find(params[:campaign_id]).voter_lists.first.voters.first.call_attempts.create(:campaign_id => params[:campaign_id])
    response = call_attempt.campaign.script.robo_recordings.first.twilio_xml(call_attempt)
    render :xml => response
  end

  def report_error
    puts "!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!Error!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!! \n\n", params.inspect
    render :text => ''
  end

  def call_ended
    puts ".......................................................Call Ended......................................\n\n", params.inspect
    render :text => ''
  end
end
