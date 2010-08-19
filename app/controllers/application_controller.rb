# Filters added to this controller apply to all controllers in the application.
# Likewise, all the methods added will be available for all controllers.

class ApplicationController < ActionController::Base
  helper :all # include all helpers, all the time
  protect_from_forgery # See ActionController::RequestForgeryProtection for details
  before_filter :controllerName, :preload_models
  # Scrub sensitive parameters from your log
  filter_parameter_logging :password
  helper_method :phone_format, :phone_number_valid  

  def preload_models
    CallAttempt
    CallerSession
    Caller
  end
  
  def controllerName
    @controllerName = self.class.controller_path
    @actionName = action_name
  end


  def phone_format(str)
    return "" if str.blank?
    str.gsub(/[^0-9]/, "")
  end

  def phone_number_valid(str)
    if (str.blank?)
      return false
    end
    str.scan(/[0-9]/).size > 9
  end

  private

  def cache_get(key)
    unless output = CACHE.get(key)
      output = yield
      CACHE.set(key, output)
    end
    return output
  end

  def cache_delete(key)
    CACHE.delete(key)
  end

  def cache_set(key)
    output = yield      
    if CACHE.get(key)==nil
       CACHE.add(key, output)
     else
       CACHE.set(key, output)
     end
  end

  def isnumber(string)
     string.to_i.to_s == string ? true : false
  end  
end
