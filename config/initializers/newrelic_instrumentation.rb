require 'new_relic/agent/method_tracer'
require 'twilio_lib'
TwilioLib.class_eval do
  include ::NewRelic::Agent::MethodTracer
  add_method_tracer :make_call, 'Custom/TwilioLib/init_call'
  add_method_tracer :make_call_em, 'Custom/TwilioLib/init_call'
end