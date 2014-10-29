module DoNotCall
  def self.s3_root
    "_system/do_not_call"
  end

  def self.ported_file_url
    ENV['WIRELESS_PORTED_URL']
  end

  def self.block_file_url
    ENV['WIRELESS_BLOCK_FILE_URL']
  end

  def self.auth_ids
    {
      ported: ported_file_url,
      block: block_file_url
    }
  end
end