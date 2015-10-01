module Windozer
  def self.to_unix(str)
    str = Windozer::String.new(str)
    str.clean_encoding!
    str.replace_carriage_returns!
    return str
  end

  class String < ::String
    BOM = /\xEF\xBB\xBF/

    def self.bom_away(str)
      Windozer.to_unix(str).gsub(BOM,'')
    end

    def bom_away!
      gsub!(BOM,'')
    end

    def replace_carriage_returns!
      gsub!(/\r\n?/, "\n")
    end

    def clean_encoding!
      force_encoding('UTF-8').encode!('UTF-16', invalid: :replace, replace: '')
      encode!('UTF-8')
    end
  end
end
