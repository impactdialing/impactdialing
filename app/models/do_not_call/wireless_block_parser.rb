require 'csv'

module DoNotCall
class WirelessBlockParser < FileParser
    def parse_line(line)
      "#{line[0]}#{line[1]}#{line[2]}"
    end

    def csv
      CSV.new(file, {headers: true})
    end

    # process file in batches, yielding each batch to the givenblock
    def in_batches(batch_size=10_000, &block)
      to_yield = []

      csv.each do |line|
        
        if identifies_wireless_device?(line)
          to_yield << parse_line(line)
        end

        if to_yield.size == batch_size && block_given?
          yield to_yield 
          to_yield = []
        end
      end

      if to_yield.size > 0 && block_given?
        yield to_yield
      end
    end

    def identifies_wireless_device?(line)
      line[3] == 'C'
    end
  end
end
