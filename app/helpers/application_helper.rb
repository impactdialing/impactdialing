# Methods added to this helper will be available to all templates in the application.
module ApplicationHelper
  include WhiteLabeling

  def flash_message(where, error_message)
    if flash[where] and flash[where].class == Array
      flash[where] = flash[where].concat [error_message]  # should not use <<. rails flash does not 'keep' them.
    elsif flash[where] and flash[where].class == String
      flash[where] = [flash[where], error_message]
    else
      flash[where] = [error_message]
    end
  end

  def flash_now(where, error_message)
    if flash.now[where] and flash.now[where].class == Array
      flash.now[where] = flash.now[where].concat [error_message]  # should not use <<. rails flash does not 'keep' them.
    elsif flash.now[where] and flash.now[where].class == String
      flash.now[where] = [flash.now[where], error_message]
    else
      flash.now[where] = [error_message]
    end
  end


  def client_controller?(controllerName)
    ['client/accounts', 'client', 'voter_lists', 'monitor', 'client/campaigns', 'client/scripts', 'client/callers', 'client/reports', 'campaigns', 'scripts', 'client/caller_groups', 'reports', 'blocked_numbers', 'monitors', 'messages'].include?(controllerName)
  end

  ['title', 'full_title', 'phone', 'email', 'billing_link'].each do |value|
    define_method(value) do
      send("white_labeled_#{value}", request.domain)
    end
  end

  def domain
    correct_domain(request.domain)
  end

  def sanitize_dials(dial_count)
    dial_count.nil? ? 0 : dial_count
  end

  def percent_dials(dial_count, total_dials)
    begin
      ((sanitize_dials(dial_count).to_f/total_dials)*100).round
    rescue FloatDomainError
      0
    end
  end

  def to_bool(value)
    return true if value == true || value =~ (/(true|t|yes|y|1)$/i)
    return false if value == false || value.blank? || value =~ (/(false|f|no|n|0)$/i)
    raise ArgumentError.new("invalid value for Boolean: \"#{value}\"")
  end


  module TimeUtils
    def round_for_utilization(seconds)
      (seconds.to_f/60).ceil.to_s
    end
  end
end
