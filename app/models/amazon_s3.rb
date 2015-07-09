class AmazonS3
  def initialize
    @config = {
      'access_key_id'     => ENV['S3_ACCESS_KEY'],
      'secret_access_key' => ENV['S3_SECRET_ACCESS_KEY'],
      'bucket'            => ENV['S3_BUCKET']
    }
    @s3 = AWS::S3.new(@config)
  end

  def object(bucket_name, file_name)
    @s3.buckets[bucket_name].objects[file_name]
  end

  def read(file_name)
    @s3.buckets[@config['bucket']].objects[file_name].read
  end

  def stream(file_name, &block)
    @s3.buckets[@config['bucket']].objects[file_name].read do |chunk|
      yield chunk
    end
  end

  def delete(file_name)
    @s3.buckets[@config['bucket']].objects[file_name].delete
  end

  def write(s3path, file)
    @s3.buckets[@config['bucket']].objects[s3path].write(file, acl: "private", content_type: "application/text")
  end

  def write_report(file_name, csv_file_name)
    expires_in_24_hours = (Time.now + 24.hours).to_i
    @s3.buckets["download_reports"].objects[file_name].write(File.open(csv_file_name), acl: "private", content_type: "application/binary",
      expires: expires_in_24_hours)
  end
end
