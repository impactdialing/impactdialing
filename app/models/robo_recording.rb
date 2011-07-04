class RoboRecording < ActiveRecord::Base
  has_attached_file :file,
                    :storage => :s3,
                    :s3_credentials => "#{RAILS_ROOT}/config/amazon_s3.yml",
                    :path=>"/:filename"
  belongs_to :script
  has_many :recording_responses
  accepts_nested_attributes_for :recording_responses, :allow_destroy => true
  before_post_process :set_content_type

  validates_presence_of :name, :message => "Please name your recording."

  def set_content_type
    self.file.instance_write(:content_type,MIME::Types.type_for(self.file_file_name).to_s)
  end

end
