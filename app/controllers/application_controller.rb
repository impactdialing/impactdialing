# Filters added to this controller apply to all controllers in the application.
# Likewise, all the methods added will be available for all controllers.
require 'new_relic/agent/method_tracer'
class ApplicationController < ActionController::Base
  include NewRelic::Agent::MethodTracer
  include WhiteLabeling
  helper :all # include all helpers, all the time
  protect_from_forgery # See ActionController::RequestForgeryProtection for details
  before_filter :set_controller_name#, :preload_models
  # Scrub sensitive parameters from your log
  helper_method :phone_format, :phone_number_valid

  # def redirect_to_ssl
  #   return true if Rails.env == 'development' || Rails.env == 'heroku_staging' || testing? || action_name=="monitor" || request.domain.index("amazonaws")
  #   return true if ssl?
  #   @cont = controller_name
  #   @act = action_name
  #   flash.keep
  #   if ['staging', 'preprod'].include?(request.subdomain)
  #     redirect_to URI.join("https://#{request.subdomain}.#{request.domain}", request.fullpath).to_s
  #   elsif ['predictive'].include?(request.subdomain)
  #     redirect_to "https://#{APP_HOST}/caller"
  #   elsif ['broadcast'].include?(request.subdomain)
  #     redirect_to "https://#{APP_HOST}/broadcast"
  #   elsif controller_name=="caller"
  #     redirect_to "https://caller.#{request.domain}/#{@cont}/#{@act}/#{params[:id]}"
  #   elsif controller_name == 'broadcast'
  #     redirect_to "https://broadcast.#{request.domain}#{request.path}"
  #   else
  #     redirect_to "https://admin.#{request.domain}/#{@cont}/#{@act}/#{params[:id]}"
  #   end
  # end
  # add_method_tracer :redirect_to_ssl, "Custom/#{self.class.name}/redirect_to_ssl"

  def testing?
    Rails.env == 'test'
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
        if voters_count < (c.length * 10)
            warning+="You are running low on numbers to dial for the #{campaign.name} campaign."
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

  def preload_models
    CallAttempt
    CallerSession
    Caller
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


  def handle_multi_disposition_submit(result_set_num,attempt_id)
    #@session
    logger.info "handle_multi_disposition_submit called for attempt #{attempt_id} result #{result_set_num}"
    return if @session.blank?
    @campaign = @session.campaign
    @script = @campaign.script
    @clean_incomplete=nil
    if @script.incompletes!=nil && @script.incompletes.index("{")
      incompletes=JSON.parse(@script.incompletes)
    else
      incompletes={}
    end


    #new style results
    attempt = CallAttempt.find(attempt_id)
    begin
      result_json=YAML.load(attempt.result_json)
    rescue
      result_json={}
    end
    logger.info "before result_json=#{result_json.inspect}"

    r=result_set_num
    this_result_set = JSON.parse(eval("@script.result_set_#{r}" ))
    thisKeypadval= params[:Digits].gsub("#","").gsub("*","").slice(0..1)
    this_result_text=this_result_set["keypad_#{thisKeypadval}"]
    result_json["result_#{r}"]=[this_result_text,thisKeypadval]
    this_incomplete = incompletes[r.to_s] || []
    logger.info "after result_json=#{result_json.inspect}"

    if this_incomplete.index(thisKeypadval.to_s)
      @clean_incomplete=true
    else
      @clean_incomplete=false
    end

    attempt = CallAttempt.find(attempt_id)
    attempt.result_json=result_json
    attempt.save

    voter = attempt.voter
    voter.result_json=result_json
    voter.save

  end
  
  

  def handle_disposition_submit
    #@session @clean_digit @caller @campaign
    if @session.voter_in_progress!=nil
      voter = Voter.find(@session.voter_in_progress)
      voter.status='Call finished'
      voter.result_digit=@clean_digit
      voter.result_date=Time.now
      voter.caller_id=@caller.id
      attempt = CallAttempt.find(@session.attempt_in_progress)
      #attempt = CallAttempt.find_by_voter_id(@session.voter_in_progress, :order=>"id desc", :limit=>1)
      attempt.result_digit=@clean_digit

      voter.attempt_id=attempt.id if attempt!=nil
      if @campaign.script!=nil
        if @clean_response.blank?
          #old format
          voter.result=eval("@campaign.script.keypad_" + @clean_digit)
          attempt.result=eval("@campaign.script.keypad_" + @clean_digit)
        else
          voter.result=@clean_response
          attempt.result=@clean_response
        end
        begin
          if @campaign.script.incompletes!=nil
            if @clean_incomplete!=nil
              voter.call_back=@clean_incomplete
            else
              #old format
              if @campaign.script.incompletes.index("{")==nil
                if eval(@campaign.script.incompletes).index(@clean_digit)
                  voter.call_back=true
                else
                  voter.call_back=false
                end
              end
            end
          end
        rescue
        end
      end
      attempt.save
      if !@family_submitted.blank?
        if @family_submitted.split("_").first=="Voter"
          #this voter (primary family member anwered)
          voter.family_id_answered=0
        else
          #another family member
          voter.family_id_answered=@family_submitted.split("_").last
        end
      end
      voter.save
    end

#    @session = CallerSession.find(params[:session])
    if @session.endtime==nil
#      @session.available_for_call=true
      @session.voter_in_progress=nil
      @session.attempt_in_progress=nil
      @session.save
    end
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

end
