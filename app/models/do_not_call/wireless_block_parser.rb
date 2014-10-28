require 'csv'

module DoNotCall
class WirelessBlockParser < FileParser
    def parse_line(line)
      "#{line[0]}#{line[1]}#{line[2]}"
    end
  end
end
