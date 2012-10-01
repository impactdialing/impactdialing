# Filters added to this controller apply to all controllers in the application.
# Likewise, all the methods added will be available for all controllers.
require 'new_relic/agent/method_tracer'
class ApplicationController < ActionController::Base
  include NewRelic::Agent::MethodTracer
  include WhiteLabeling
  include ApplicationHelper
  helper :all # include all helpers, all the time
  protect_from_forgery # See ActionController::RequestForgeryProtection for details
  rescue_from InvalidDateException, :with=> :return_invalid_date
  
  def select_shard(&block)
      Octopus.using(:read_slave1, &block)
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
