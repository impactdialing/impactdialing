require 'spec_helper'
require 'windozer'

describe Windozer do
  def windozed_file
    File.join( File.dirname(__FILE__), '..', 'fixtures', 'files', 'windoze_voters_list.csv' )
  end

  def carriage_and_newline_file
    <<-EOF
phone,first,last,city,country,party\r
5554321839,John,Middle,Any City,USA,\r
2839587371,Sara,Jane,Other City,USA,\r
    EOF
  end

  describe '.to_unix(str)' do
    it 'removes invalid UTF-16 characters' do
      blurged_file = File.open(windozed_file).read

      expect{ blurged_file.gsub('a', 'a') }.to raise_error ArgumentError

      cleaned = Windozer.to_unix(blurged_file)

      cleaned.gsub('a', 'a')
      expect(cleaned).not_to include("\r")
    end

    it 'does not double the number of lines by adding empties' do
      cleaned = Windozer.to_unix(carriage_and_newline_file)
      expect(cleaned).not_to include("\r")
      expect(cleaned.split("\n").size).to(eq(3), cleaned)
    end
  end
end