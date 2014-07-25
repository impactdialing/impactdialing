require "spec_helper"

describe Recording, :type => :model do
  it { is_expected.to validate_presence_of(:file_file_name).with_message(/File can't be blank/) }
  it { is_expected.to validate_presence_of :name }

  ['mp3', 'aif', 'aiff', 'wav'].each do |extension|
    it "accepts files with an extension of #{extension}" do
      recording = build(:recording, :file_file_name => "foo.#{extension}")
      expect(recording).to be_valid
    end
  end

  it "is not valid with a file of a different extension" do
    recording = build(:recording, :file_file_name => 'foo.swf')
    expect(recording).not_to be_valid
    expect(recording.errors[:base]).to include("Filetype swf is not supported.  Please upload a file ending in .mp3, .wav, or .aiff")
  end

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
