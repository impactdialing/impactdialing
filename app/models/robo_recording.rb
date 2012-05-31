class RoboRecording < ActiveRecord::Base
  include Rails.application.routes.url_helpers

  has_attached_file :file,
                    :storage => :s3,
                    :s3_credentials => Rails.root.join('config', 'amazon_s3.yml').to_s,
                    :path=>"/:filename"
  belongs_to :script
  has_many :recording_responses
  accepts_nested_attributes_for :recording_responses, :allow_destroy => true
  has_many :call_responses
  before_post_process :set_content_type
  
  scope :responded_by, lambda { |voter| joins(:call_responses).where("call_responses.call_attempt_id = ?", voter.last_call_attempt.id) }
  scope :not_responded_by, lambda { |voter| order("id ASC").where("robo_recordings.id not in (?)", RoboRecording.responded_by(voter).collect(&:id) + [-1]) }

  validates_presence_of :name, :message => "Please name your recording."
  validates_attachment_content_type :file, :content_type => ['audio/mpeg', 'audio/wav', 'audio/wave', 'audio/x-wav', 'audio/aiff', 'audio/x-aifc', 'audio/x-aiff', 'audio/x-gsm', 'audio/gsm', 'audio/ulaw']

  def set_content_type
    self.file.instance_write(:content_type, MIME::Types.type_for(self.file_file_name).first)
  end

  def next
    script.robo_recordings.where("id > #{self.id}").first
  end


  def response_for(digits)
    self.recording_responses.find_by_keypad(digits)
  end
  
  def answered_within(from_date, to_date, campaign_id)
    call_responses.within(from_date, to_date, campaign_id)
  end
  
  def twilio_xml(call_attempt)
    ivr_url = twilio_create_call_url(:host => Settings.host, :id => call_attempt.id, :robo_recording_id => self.id)
    recording_responses.count > 0 ? ivr_prompt(ivr_url) : play_message(call_attempt)
  end

  def hangup
    Twilio::Verb.new { |v| v.hangup }.response
  end

  def play_message(call_attempt)
    verb = Twilio::Verb.new do |v|
      recording = self
      while (recording) do
        unless recording.recording_responses.empty?
          recording.prompt_message(twilio_create_call_url(:host => Settings.host, :id => call_attempt.id, :robo_recording_id => recording.id), v)
          break
        end
        v.play URI.escape(recording.file.url)
        recording = recording.next
      end
    end
    verb.response
  end

  def prompt_message(ivr_url, verb)
    3.times do
      verb.gather(:numDigits => 1, :timeout => 10, :action => ivr_url, :method => "POST") do
        verb.play URI.escape(self.file.url)
      end
    end
  end

  def ivr_prompt(ivr_url)
    verb = Twilio::Verb.new do |v|
      prompt_message(ivr_url, v)
    end
    verb.response
  end

end
