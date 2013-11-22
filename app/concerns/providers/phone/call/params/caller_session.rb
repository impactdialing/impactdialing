class Providers::Phone::Call::Params::CallerSession
  attr_reader :caller_session, :caller, :type

  include Rails.application.routes.url_helpers

  def initialize(caller_session, type=:default)
    @caller_session = caller_session
    @caller         = caller_session.caller
    @type           = type
  end

  def return_url?
    return caller_session.available_for_call? || caller_session.campaign.type != Campaign::Type::PREDICTIVE
  end

  def url_options
    return Providers::Phone::Call::Params.default_url_options.merge({
      session_id: caller_session.id
    })
  end

  def call_sid
    return caller_session.sid
  end

  def url
    method_name = "#{type}_url"
    return send(method_name)
  end

  def default_url
    if caller.is_phones_only?
      return ready_to_call_caller_url(caller, url_options)
    else
      return continue_conf_caller_url(caller, url_options)
    end
  end

  def out_of_numbers_url
    if return_url?
      return run_out_of_numbers_caller_url(caller, url_options)
    end
  end

  def time_period_exceeded_url
    if return_url?
      return time_period_exceeded_caller_url(caller, url_options)
    end
  end

  def account_has_no_funds_url
    if return_url?
      return account_out_of_funds_caller_url(caller, url_options)
    end
  end
end