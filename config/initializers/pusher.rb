require "pusher"

PUSHER_APP_ID = ENV['PUSHER_APP_ID']
PUSHER_KEY    = ENV['PUSHER_KEY']
PUSHER_SECRET = ENV['PUSHER_SECRET']
Pusher.app_id = PUSHER_APP_ID
Pusher.key    = PUSHER_KEY
Pusher.secret = PUSHER_SECRET

if Rails.env == 'test'
  module Pusher
    def self.[](*args)
      PusherObject.new
    end
  end

  class PusherObject
    def trigger(*args)
    end
  end
end
