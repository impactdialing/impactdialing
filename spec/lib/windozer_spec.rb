require 'spec_helper'
require 'windozer'

describe Windozer do
  def windozed_file
    File.join( File.dirname(__FILE__), '..', 'fixtures', 'files', 'windoze_voters_list.csv' )
  end

  describe '.to_unix(str)' do
    it 'removes invalid UTF-16 characters' do
      blurged_file = File.open(windozed_file).read

      expect{ blurged_file.gsub('a', 'a') }.to raise_error ArgumentError

      cleaned = Windozer.to_unix(blurged_file)

      cleaned.gsub('a', 'a')
      expect(cleaned).not_to include("\r")
    end
  end
end