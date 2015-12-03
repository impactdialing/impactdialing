module TokenGenerator
  def self.sha_hexdigest(*args)
    return Digest::SHA1.hexdigest(args.flatten.join('--'))
  end

  def self.uuid
    uuid = UUID.new
    uuid.generate
  end
end
