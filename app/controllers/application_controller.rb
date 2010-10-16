# Filters added to this controller apply to all controllers in the application.
# Likewise, all the methods added will be available for all controllers.

class ApplicationController < ActionController::Base
  helper :all # include all helpers, all the time
  protect_from_forgery # See ActionController::RequestForgeryProtection for details
  before_filter :controllerName#, :preload_models
  # Scrub sensitive parameters from your log
  filter_parameter_logging :password
  helper_method :phone_format, :phone_number_valid  
  
  def warning_text
    return "" if @user==nil
    warning=""
    @user.campaigns.each do |campaign|
      c = CallerSession.find_all_by_campaign_id_and_on_call(campaign.id,1)
      if c.length > 0
        voters = campaign.voters_count("not called")
        if voters.length < c.length * 10
            warning+="
            You are running low on numbers to dial for the #{campaign.name} campaign.
            Unless you act quickly, you'll have called through all your lists in
            about 30 minutes. You have three choices.<br/><br/>
            1: Load up some more numbers. This is the best option, if you have
            another list ready to go. If it's already loaded up, just add it to
            this dialing group.<br/><br/>
            2. Cycle back through the list another time. Generally, it's a good
            idea not to call through the same list twice in one session, because
            if someone didn't pick up before, chances are they won't pick up now,
            and the people who said to call back might be pissed that you called
            back so quickly. We'll dial really aggressively to try to find numbers
            that will answer, but this will also cause more calls to be dropped.<br/><br/>
            3. Do nothing and end the calling for this shift. If you don't have
            more numbers and the calling shift is almost over anyways, this is
            your best option.<br/><br/>

            If you don't choose one of these options, we'll choose number 2 for
            you when your numbers run out.<br/><br/>"
          end
        end
      end
    warning
  end
  
  def unpaid_text
    return "" if @user==nil
    warning=""
    if !@user.paid?
      warning= "Your account is not funded and cannot make calls. For a free
      trial or to fund your account, email <a href=\"mailto:info@impactdialing.com\">info@impactdialing.com</a> or call
      (415) 347-5723."
    end
    warning
  end  

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

  def send_rt(key, post_data)
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
        voter.result=eval("@campaign.script.keypad_" + @clean_digit)
        attempt.result=eval("@campaign.script.keypad_" + @clean_digit)
        begin
          if @campaign.script.incompletes!=nil
            if eval(@campaign.script.incompletes).index(@clean_digit)
              voter.call_back=true
            end
          end
        rescue
        end
      end
      attempt.save
      voter.save
    end

#    @session = CallerSession.find(params[:session]) 
    if @session.endtime==nil
      @session.available_for_call=true
      @session.voter_in_progress=nil
      @session.attempt_in_progress=nil
      @session.save
    end
  end


end
