class CallFlow::Web::Util
  extend ERB::Util

  def self.autolink(text)
    domain_regex = /[\w]+[\w\.\-]?(\.[a-z]){1,2}/i
    email_regex  = /[\w\-\.]+[\w\-\+\.]?@/i
    proto_regex  = /\bhttp(s)?:\/\//i
    space_regex  = /\s+/
    stripped_text = text.kind_of?(String) ? text.strip : text

    if stripped_text =~ domain_regex and stripped_text !~ space_regex
      # it looks like a domain, is it an email?
      if stripped_text =~ email_regex
        return "<a target=\"_blank\" href=\"mailto:#{html_escape(text)}\">#{html_escape(text)}</a>"
      else
        proto = text =~ proto_regex ? '' : 'http://'
        return "<a target=\"_blank\" href=\"#{proto}#{html_escape(text)}\">#{html_escape(text)}</a>"
      end
    end

    html_escape(text)
  end

  def self.linked?(string)
    string =~ /.*<a\s.*>.*<\/a>.*/
  end

  def self.filter(whitelisted_keys, data)
    return data if data.nil?

    out = {}
    
    data.each do |key,value|
      if (mapped_value = VoterList::VOTER_DATA_COLUMNS[key]).blank?
        mapped_value = key
      end

      if whitelisted_keys.include?(mapped_value)
        if not linked?(value)
          out[key] = autolink(value)
        else
          out[key] = value
        end
      end
    end

    out
  end
end

