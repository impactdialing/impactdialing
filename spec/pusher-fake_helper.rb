require "pusher-fake/cucumber"
# Pusher.host = PusherFake.configuration.web_host
# Pusher.port = PusherFake.configuration.web_port


# PusherFake.configure do |configuration|
#   configuration.app_id = "PUSHER_APP_ID"
#   configuration.key    = "PUSHER_API_KEY"
#   configuration.secret = "PUSHER_API_SECRET"
# end


# fork { PusherFake::Server.start }.tap do |id|
#   at_exit { Process.kill("KILL", id) }
# end