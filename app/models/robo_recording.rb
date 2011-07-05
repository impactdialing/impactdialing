class RoboRecording < ActiveRecord::Base
  include ActionController::UrlWriter

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
    self.file.instance_write(:content_type, MIME::Types.type_for(self.file_file_name).to_s)
  end

  def next
    self.script.robo_recordings.find(:first, :conditions => ["id > ?", self.id])
  end

  def response_for(digits)
    self.recording_responses.find_by_keypad(digits)
  end

  # @param call_attempt [Object]
  def twilio_xml(call_attempt)
    url = call_attempts_url(:host => '3njb.localtunnel.com', :id => call_attempt.id, :robo_recording_id => self.id)
    verb = Twilio::Verb.new do |v|
      v.gather(:numDigits => 1, :timeout => 10, :action => url, :method => "POST") do
        v.play URI.escape(self.file.url)
      end
    end
    verb.response
  end

end
