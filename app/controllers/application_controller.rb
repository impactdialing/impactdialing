# Filters added to this controller apply to all controllers in the application.
# Likewise, all the methods added will be available for all controllers.
require 'new_relic/agent/method_tracer'
class ApplicationController < ActionController::Base
  include NewRelic::Agent::MethodTracer
  include WhiteLabeling
  # include ApplicationHelper
  helper :all # include all helpers, all the time
  protect_from_forgery # See ActionController::RequestForgeryProtection for details
  before_filter :set_controller_name
  # Scrub sensitive parameters from your log
  helper_method :phone_format, :phone_number_valid
  rescue_from Timeout::Error, :with => :return_service_unavialble
  rescue_from InvalidDateException, :with=> :return_invalid_date

  def testing?
    Rails.env == 'test'
  end
  
  def return_service_unavialble
    respond_to do |type|
      type.all  { render :nothing => true, :status => 503 }
    end
    true
  end
  
  def return_invalid_date
    flash_message(:error, I18n.t(:invalid_date_format))
    redirect_to :back    
  end
  

  def ssl?
    request.env['HTTPS'] == 'on' || request.env['HTTP_X_FORWARDED_PROTO'] == 'https'
  end

  def warning_text
    return "" if @user==nil
    warning=""
    @user.account.campaigns.each do |campaign|
      c = CallerSession.find_all_by_campaign_id_and_on_call(campaign.id,1)
      if c.length > 0
        voters_count = campaign.voters_count("not called")
        begin
          if voters_count < (c.length * 10)
              warning+="You are running low on numbers to dial for the #{campaign.name} campaign."
          end
        rescue Exception => e
          # do nothing
        end
      end
    end
    warning
  end

  def unpaid_text
    if current_user && !current_user.account.card_verified?
      I18n.t(:unpaid_text, :billing_link => billing_link(self.active_layout.instance_variable_get(:@template_path))).html_safe
    else
      ""
    end
  end

  def unactivated_text
    if current_user && !current_user.account.activated?
      I18n.t(:unactivated_text).html_safe
    else
      ""
    end
  end

  def active_layout
    send(:_layout)
  end

  def billing_link(layout)
    '<a href="' + white_labeled_billing_link(request.domain) + '">Click here to verify a credit card.</a>'
  end

  def set_controller_name
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

  def generate_session_key
    secure_digest(Time.now, (1..10).map{ rand.to_s })
  end

  def secure_digest(*args)
    Digest::SHA1.hexdigest(args.flatten.join('--'))
  end

  def format_number_to_phone(number, options = {})
    number       = number.to_s.strip unless number.nil?
    options      = options.symbolize_keys
    area_code    = options[:area_code] || nil
    delimiter    = options[:delimiter] || "-"
    extension    = options[:extension].to_s.strip || nil
    country_code = options[:country_code] || nil

    begin
      str = ""
      str << "+#{country_code}#{delimiter}" unless country_code.blank?
      str << if area_code
      number.gsub!(/([0-9]{1,3})([0-9]{3})([0-9]{4}$)/,"(\\1) \\2#{delimiter}\\3")
      else
        number.gsub!(/([0-9]{0,3})([0-9]{3})([0-9]{4})$/,"\\1#{delimiter}\\2#{delimiter}\\3")
        number.starts_with?('-') ? number.slice!(1..-1) : number
      end
      str << " x #{extension}" unless extension.blank?
      str
    rescue
      number
    end
  end

  def send_rt_old(key, post_data)
    # msg_url="https://#{TWILIO_AUTH}:x@#{TWILIO_ACCOUNT}.twiliort.com/#{key}"
    http = Net::HTTP.new("#{TWILIO_ACCOUNT}.twiliort.com", 443)
    req = Net::HTTP::Post.new("/#{key}")
    http.use_ssl = true
    req.basic_auth TWILIO_AUTH, "x"
    req.set_form_data(post_data, ';')
    response = http.request(req)
    logger.info "SENT RT #{key} #{post_data}: #{response.body}"
    return response.body
  end

  def send_rt(channel, key, post_data)
    require 'pusher'
    Pusher.app_id = PUSHER_APP_ID
    Pusher.key = PUSHER_KEY
    Pusher.secret = PUSHER_SECRET
    Pusher[channel].trigger(key, post_data)
    logger.info "SENT RT #{key} #{post_data} #{channel}"
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
