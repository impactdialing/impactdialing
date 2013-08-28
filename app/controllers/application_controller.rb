# Filters added to this controller apply to all controllers in the application.
# Likewise, all the methods added will be available for all controllers.
require 'new_relic/agent/method_tracer'
class ApplicationController < ActionController::Base
  include NewRelic::Agent::MethodTracer
  include WhiteLabeling
  include ApplicationHelper
  helper :all # include all helpers, all the time
  protect_from_forgery # See ActionController::RequestForgeryProtection for details
  # Scrub sensitive parameters from your log
  rescue_from InvalidDateException, :with=> :return_invalid_date
  rescue_from CanCan::AccessDenied do |exception|
    redirect_to root_url, :alert => exception.message
  end

  def current_ability
    @current_ability ||= Ability.new(account)
  end

  def select_shard(&block)
      Octopus.using(OctopusConnection.dynamic_shard(:read_slave1, :read_slave2), &block)
  end

  def return_invalid_date
    flash_message(:error, I18n.t(:invalid_date_format))
    redirect_to :back
  end

  private

  def generate_session_key
    secure_digest(Time.now, (1..10).map{ rand.to_s })
  end

  def secure_digest(*args)
    Digest::SHA1.hexdigest(args.flatten.join('--'))
  end

  def full_access
    if @user.supervisor?
      flash_message(:error, I18n.t(:admin_access))
      redirect_to '/client'
      return
    end
  end

  def sanitize_dials(dial_count)
    dial_count.nil? ? 0 : dial_count
  end
end
