module Windozer
  def self.to_unix(str)
    str = Windozer::String.new(str)
    str.clean_encoding!
    str.replace_carriage_returns!
    return str
  end

  class String < ::String
    def replace_carriage_returns!
      gsub!(/\r\n?/, "\n")
    end

    def clean_encoding!
      force_encoding('UTF-8').encode!('UTF-16', invalid: :replace, replace: '')
      encode!('UTF-8')
    end
  end
end
