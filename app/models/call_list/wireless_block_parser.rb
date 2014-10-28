require 'csv'

class WirelessBlockParser
  attr_reader :file

  def initialize(file)
    @file = file
  end

  # process file in batches, yielding each batch to the givenblock
  def in_batches(batch_size=10_000, &block)
    csv      = CSV.new(file, {headers: true})
    to_yield = []

    csv.each do |line|
      to_yield << "#{line[0]}#{line[1]}#{line[2]}"
      if to_yield.size == batch_size && block_given?
        yield to_yield 
        to_yield = []
      end
    end

    yield to_yield if to_yield.size > 0 && block_given?
  end
end