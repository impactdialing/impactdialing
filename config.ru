# This file is used by Rack-based servers to start the application.

require ::File.expand_path('../config/environment',  __FILE__)
run ImpactDialing::Application

run Rack::URLMap.new \
  "/"       => ImpactDialing::Application,
  "/resque" => Resque::Server.new

