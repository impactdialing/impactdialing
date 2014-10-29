require 'csv'

module DoNotCall
class WirelessBlockParser < FileParser
    def parse_line(line)
      "#{line[0]}#{line[1]}#{line[2]}"
    end

    def csv
      CSV.new(file, {headers: true})
    end
  end
end
