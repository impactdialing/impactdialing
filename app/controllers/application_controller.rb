# Filters added to this controller apply to all controllers in the application.
# Likewise, all the methods added will be available for all controllers.
require 'new_relic/agent/method_tracer'
class ApplicationController < ActionController::Base
  include NewRelic::Agent::MethodTracer
  include WhiteLabeling
  include ApplicationHelper
  include Pundit
  helper :all # include all helpers, all the time
  protect_from_forgery # See ActionController::RequestForgeryProtection for details

  respond_to :html, :json

  # Scrub sensitive parameters from your log
  rescue_from InvalidDateException, :with=> :return_invalid_date
  rescue_from CanCan::AccessDenied do |exception|
    redirect_to root_url, :error => exception.message
  end
  rescue_from Pundit::NotAuthorizedError do
    respond_to do |format|
      format.json{ render json: {message: I18n.t(:admin_access)} }
      format.html{
        flash_message(:error, I18n.t(:admin_access));
        redirect_to root_path
      }
    end
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

  def sanitize_dials(dial_count)
    dial_count.nil? ? 0 : dial_count
  end
end
