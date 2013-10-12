module Windozer
  def self.to_unix(str)
    str = Windozer::String.new(str)
    str.clean_encoding!
    str.replace_carriage_returns!
    return str
  end

  class String < ::String
    def replace_carriage_returns!
      gsub!("\r", "\n")
    end

    def clean_encoding!
      encode!('UTF-16', invalid: :replace, replace: '')
      encode!('UTF-8')
    end
  end
end
