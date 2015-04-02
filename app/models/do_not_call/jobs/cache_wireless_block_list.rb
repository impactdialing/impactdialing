# https://www.qscdl.com/download/nalennd_block.zip

require 'tempfile'
require 'uri'
require 'zip'
require 'librato_resque'

module DoNotCall::Jobs
  class CacheWirelessBlockList
    extend LibratoResque
    @queue = :general

    def self.url
      ENV['DO_NOT_CALL_WIRELESS_BLOCK_LIST_PROVIDER_URL']
    end

    def self.perform(s3_root_path)
      temp_file      = download
      filename, file = *unzip(temp_file)
      dest_path      = "#{s3_root_path}/#{filename}"
      AmazonS3.new.write(dest_path, file)

      Resque.enqueue(DoNotCall::Jobs::RefreshWirelessBlockList, filename)
    end

    def self.download
      uri     = URI.parse(url)
      faraday = Faraday.new("#{uri.scheme}://#{uri.host}")
      faraday.basic_auth(uri.user, uri.password)
      response = faraday.get(uri.path)
      
      save_temp_file(response.body)
    end

    def self.save_temp_file(contents)
      temp_file = Tempfile.new('wireless_block_list', encoding: 'ascii-8bit')
      temp_file.write(contents)
      temp_file.close
      temp_file
    end

    def self.unzip(temp_file)
      unzipped_file     = nil
      unzipped_filename = nil
      ::Zip::File.open(temp_file.path) do |zip_file|
        entry             = zip_file.glob('*.csv').first
        unzipped_filename = entry.name
        unzipped_file     = entry.get_input_stream.read
      end
      return [unzipped_filename, unzipped_file]
    end
  end
end
