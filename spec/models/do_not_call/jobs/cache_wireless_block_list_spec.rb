require 'rails_helper'

describe DoNotCall::Jobs::CacheWirelessBlockList, data_heavy: true, cell_lists: true do
  subject{ DoNotCall::Jobs::CacheWirelessBlockList }
  let(:s3_config) do
    {
      'access_key_id'     => ENV['S3_ACCESS_KEY'],
      'secret_access_key' => ENV['S3_SECRET_ACCESS_KEY'],
      'bucket'            => ENV['S3_BUCKET']
    }
  end
  let(:s3_connection){ AWS::S3.new(access_key_id: s3_config['access_key_id'], secret_access_key: s3_config['secret_access_key']) }

  it 'downloads the nalennd_block.zip file' do
    VCR.use_cassette('cache wireless block list download file') do
      file = subject.download
      expect(file.size).to be > 3_000_000
    end
  end
  it 'unzips the nalennd_block.zip file' do
    # used cached request from previous test
    VCR.use_cassette('cache wireless block list download file') do
      file = subject.download
      expect(subject.unzip(file).last.size).to be > 20_000_000
    end
  end
  it 'caches the unzipped nalennd_block file to s3' do
    VCR.use_cassette('cache wireless block list to s3') do
      filename     = 'nalennd_block.csv'
      s3_root_path = "_system/do_not_call/test"

      subject.perform(s3_root_path)

      s3_keys = s3_connection.buckets[s3_config['bucket']].objects.with_prefix(s3_root_path).map(&:key)
      expect(s3_keys).to include "#{s3_root_path}/#{filename}"
    end
  end
end
