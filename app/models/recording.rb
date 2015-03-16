require "paperclip"

class Recording < ActiveRecord::Base
  attr_accessible :file_file_name, :name, :file

  validates_presence_of :name

  belongs_to :account
  has_many :campaigns

  scope :active, -> { where(:active => true) }

  has_attached_file :file,
                    :storage => :s3,
                    :s3_credentials => Rails.root.join('config', 'amazon_s3.yml').to_s,
                    :s3_protocol => 'https', # force https
                    :path => "/#{Settings.recording_env}/uploads/:account_id/:id.:extension",
                    :default_url => '' # avoid generating default urls

  validates_attachment_content_type(:file, {
    content_type: [
      'audio/wav', 'audio/x-wav', 'audio/vnd.wave',
      'audio/mpeg3', 'audio/x-mpeg-3', 'audio/mpeg',
      'audio/aiff', 'audio/x-aiff'
    ],
    message: 'Please upload an audio file encoded with one of WAV, MP3, or AIF.'
  })
  validates_attachment_presence :file
end

# ## Schema Information
#
# Table name: `recordings`
#
# ### Columns
#
# Name                     | Type               | Attributes
# ------------------------ | ------------------ | ---------------------------
# **`id`**                 | `integer`          | `not null, primary key`
# **`account_id`**         | `integer`          |
# **`active`**             | `integer`          | `default(1)`
# **`name`**               | `string(255)`      |
# **`created_at`**         | `datetime`         |
# **`updated_at`**         | `datetime`         |
# **`file_file_name`**     | `string(255)`      |
# **`file_content_type`**  | `string(255)`      |
# **`file_file_size`**     | `string(255)`      |
# **`file_updated_at`**    | `datetime`         |
#
