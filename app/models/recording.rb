class Recording < ActiveRecord::Base
  has_attached_file :file,
                    :storage => :s3,
                    :s3_credentials => "#{RAILS_ROOT}/config/amazon_s3.yml",
                    :path=>"/:filename"
  belongs_to :script
end
