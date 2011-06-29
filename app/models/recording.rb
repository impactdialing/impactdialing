class Recording < ActiveRecord::Base
  has_attached_file :file,
                    :storage => :s3,
                    :s3_credentials => "#{RAILS_ROOT}/config/amazon_s3.yml",
                    :path=>"/:filename"
  belongs_to :script
  has_many :recording_responses
  accepts_nested_attributes_for :recording_responses, :reject_if => lambda { |a| a[:keypad].blank? }, :allow_destroy => true
end
