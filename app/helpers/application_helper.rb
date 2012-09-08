# Methods added to this helper will be available to all templates in the application.
module ApplicationHelper
  include WhiteLabeling

  def client_controller?(controllerName)
    ['client/accounts', 'client', 'voter_lists', 'monitor', 'client/campaigns', 'client/scripts', 'client/callers', 'client/reports', 'campaigns', 'scripts', 'client/caller_groups', 'reports', 'home', 'blocked_numbers', 'monitors', 'messages'].include?(controllerName)
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

  module TimeUtils
    def round_for_utilization(seconds)
      (seconds.to_f/60).ceil.to_s
    end
  end
end
