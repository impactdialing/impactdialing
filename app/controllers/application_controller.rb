# Filters added to this controller apply to all controllers in the application.
# Likewise, all the methods added will be available for all controllers.
class ApplicationController < ActionController::Base
  include WhiteLabeling
  include ApplicationHelper
  helper :all # include all helpers, all the time
  protect_from_forgery # See ActionController::RequestForgeryProtection for details

  # Scrub sensitive parameters from your log
  rescue_from InvalidDateException, :with=> :return_invalid_date
  rescue_from CanCan::AccessDenied do |exception|
    redirect_to root_url, :alert => exception.message
  end
  rescue_from Report::SelectiveDateRange::InvalidDateFormat, with: :rescue_invalid_date

protected
  def self.instrument_actions?
    ENV['INSTRUMENT_ACTIONS'].to_i > 0
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

  def rescue_invalid_date(exception)
    flash[:error] = [exception.message]
    redirect_to :back
  end


private
  def generate_session_key
    CallFlow.generate_token
  end

  def sanitize_dials(dial_count)
    dial_count.nil? ? 0 : dial_count
  end
end
