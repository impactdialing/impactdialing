require "pusher"

Pusher.app_id = PUSHER_APP_ID
Pusher.key = PUSHER_KEY
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
