class TwilioController < ApplicationController
  include ::Twilio

  def callback
    call_attempt = Campaign.find(params[:campaign_id]).voter_lists.first.voters.first.call_attempts.create(:campaign_id => params[:campaign_id])
    verb = Twilio::Verb.new { |v|
      call_attempt.campaign.script.robo_recordings.each do |robo_recording|

        url = call_attempts_url(:host => '3vhu.localtunnel.com', :id => call_attempt.id, :robo_recording_id => robo_recording.id)
        puts "-----------------------------------\n\n#{url}\n\n\n\n"
        v.gather :numDigits => 2, :timeout => 10, :action => url, :method => "POST" do
          v.play robo_recording.file.url
        end
        v.say "We did not receive anything"
      end
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
