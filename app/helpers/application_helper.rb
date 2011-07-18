# Methods added to this helper will be available to all templates in the application.
module ApplicationHelper
  def cms(key)
    s = Seo.find_by_crmkey_and_active_and_version(key, 1, session[:seo_version])
    s = Seo.find_by_crmkey_and_active_and_version(key, 1, nil) if s.blank?

    if s.blank?
      ""
    else
      s.content
    end
  end

  def float_sidebar
    @floatSidebar="<script>
    $('content').style.float='right';
    $('sidebar').style.float='left';

      var obj = document.getElementById('sidebar');
      if (obj.style.styleFloat) {
          obj.style.styleFloat = 'left';
      } else {
          obj.style.cssFloat = 'left';
      }

      var obj = document.getElementById('content');
      if (obj.style.styleFloat) {
          obj.style.styleFloat = 'right';
      } else {
          obj.style.cssFloat = 'right';
      }

      </script>";
      ""
  end

  def send_rt(channel, key, post_data)
    require 'pusher'
    Pusher.app_id = PUSHER_APP_ID
    Pusher.key = PUSHER_KEY
    Pusher.secret = PUSHER_SECRET
    Pusher[channel].trigger(key, post_data)
    logger.info "SENT RT #{key} #{post_data} #{channel}"
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

  def hash_from_voter_and_script(script,voter)
    publish_hash={:id=>voter.id, :classname=>voter.class.to_s}
    #    publish_hash={:id=>voter.id}
    if !script.voter_fields.nil?
      fields = JSON.parse(script.voter_fields)
      fields.each do |field|
        #        logger.info "field: #{field}"
        publish_hash[field] = eval("voter.#{field}")
      end
    end
    publish_hash
  end

  def client_controller?(controllerName)
    ['client', 'voter_lists', 'client/campaigns', 'client/scripts', 'client/callers', 'campaigns', 'scripts'].include?(controllerName)
  end

  ['title', 'full_title', 'phone', 'email', ].each do |value|
    define_method(value)do
      t("white_labeling.#{domain}.#{value}")
    end
  end

  def domain
    d = request.domain.downcase.gsub(/\.com/, '')
    if t("white_labeling.#{d}", :default => '').blank?
      'impactdialing'
    else
      d
    end
  end
end
