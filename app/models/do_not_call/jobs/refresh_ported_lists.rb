module DoNotCall::Jobs
  class RefreshPortedLists
    def self.perform
      DoNotCall::PortedList.filenames.each do |filename|
        filepath = DoNotCall.s3_filepath(filename)
        namespace = DoNotCall::PortedList.infer_namespace(filename)
        file = AmazonS3.new.read(filepath)
        DoNotCall::PortedList.cache(namespace, file)
      end
    end
  end
end