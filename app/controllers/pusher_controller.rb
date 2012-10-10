class PusherController < ApplicationController
  
  def add_channel
  end

  def webhook
    webhook = Pusher::WebHook.new(request)
    if webhook.valid?
      webhook.events.each do |event|
        case event["name"]
        when 'channel_occupied'

        when 'channel_vacated'
        end
      end
      render text: 'ok'
    else
      render text: 'invalid', status: 401
    end
  end

end