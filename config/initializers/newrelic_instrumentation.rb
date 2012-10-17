require 'new_relic/agent/method_tracer'
require 'twilio_lib'
TwilioLib.class_eval do
  include ::NewRelic::Agent::MethodTracer
  add_method_tracer :make_call
end