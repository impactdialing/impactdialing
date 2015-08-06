##
# Provides URL helpers to determine where to redirect
# callees.
#
class Providers::Phone::Call::Params::Call
  attr_reader :call_sid

  include Rails.application.routes.url_helpers

  def initialize(call_sid, type=:default)
    @call_sid = call_sid
  end

  def url_options
    return Providers::Phone::Call::Params.default_url_options.merge({})
  end

  def url
    twiml_lead_play_message_url(url_options)
  end
end
