##
# Provides URL helpers to determine where to redirect
# callees.
#
class Providers::Phone::Call::Params::Call
  attr_reader :active_call

  include Rails.application.routes.url_helpers

  def initialize(active_call, type=:default)
    @active_call = active_call
  end

  def url_options
    return Providers::Phone::Call::Params.default_url_options.merge({})
  end

  def url
    play_message_call_url(@active_call, url_options)
  end
end