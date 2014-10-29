module DoNotCall::Jobs
  class RefreshWirelessBlockList
    def self.perform(filename)
      filepath = DoNotCall::WirelessBlockList.filepath(filename)
      file     = AmazonS3.new.read(filepath)
      DoNotCall::WirelessBlockList.cache(file)
    end
  end
end