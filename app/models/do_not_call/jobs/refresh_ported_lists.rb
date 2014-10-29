module DoNotCall::Jobs
  class RefreshPortedLists

    def self.perform
      DoNotCall::PortedList.filenames.each do |filename|
        filepath = DoNotCall::PortedList.s3_filepath(filename)
        file = AmazonS3.new.read(filepath)
        DoNotCall::PortedList.cache(file)
      end
    end
  end
end