require 'rails_helper'
require 'uri'

describe 'DoNotCall::Jobs::CacheProviderFile.perform', data_heavy: true, cell_lists: true do
  let(:s3_config) do
    {
      'access_key_id'     => ENV['S3_ACCESS_KEY'],
      'secret_access_key' => ENV['S3_SECRET_ACCESS_KEY'],
      'bucket'            => ENV['S3_BUCKET']
    }
  end
  let(:s3_connection){ AWS::S3.new(access_key_id: s3_config['access_key_id'], secret_access_key: s3_config['secret_access_key']) }
  subject{ DoNotCall::Jobs::CachePortedLists }

  it 'downloads files' do
    VCR.use_cassette('cache ported lists provider download file') do
      filename = subject.source_filenames.first
      response = subject.download(filename)
      expect(response.body.size).to be > 10_000_000
    end
  end

  it 'copies each remote file in .source_filenames to configured s3 bucket in "_system/do_not_call/"' do
    puts 'this can take a really long time to download and upload, so you may want to disable it'
    VCR.use_cassette('cache ported wireless numbers lists to s3') do
      s3_root = "_system/do_not_call/test"
      subject.perform(s3_root)

      s3_keys  = s3_connection.buckets[s3_config['bucket']].objects.with_prefix(s3_root).map(&:key)
      subject.source_filenames.each do |filename|
        expect(s3_keys).to include "#{s3_root}/#{filename}"
      end
    end
  end
end
