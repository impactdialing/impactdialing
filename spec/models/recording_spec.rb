require 'rails_helper'

describe Recording, :type => :model do
  it { should have_attached_file :file }
  it { should validate_attachment_presence :file }
  it { should validate_attachment_content_type(:file).
        allowing('audio/wav', 'audio/x-wav', 'audio/vnd.wave',
          'audio/mpeg3', 'audio/x-mpeg-3', 'audio/mpeg', 'audio/mp3',
          'audio/aiff', 'audio/x-aiff').
        rejecting('text/html', 'text/xml', 'image/jpg',
          'application/vnd.ms-excel',
          'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet') }

  it "should return active recordings" do
    active_recording = create(:recording, :active => true)
    inactive_recording = create(:recording, :active => false)

    expect(Recording.active).to eq([active_recording])
  end
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
