module DoNotCall::Jobs
  class RefreshWirelessBlockList
    extend LibratoResque
    @queue = :general
    
    def self.perform(filename)
      filepath = DoNotCall.s3_filepath(filename)
      file     = AmazonS3.new.read(filepath)
      DoNotCall::WirelessBlockList.cache(file)
    end
  end
end