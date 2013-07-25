require "spec_helper"

describe Recording do
  it { should validate_presence_of(:file_file_name).with_message(/File can't be blank/) }
  it { should validate_presence_of :name }

  ['mp3', 'aif', 'aiff', 'wav'].each do |extension|
    it "accepts files with an extension of #{extension}" do
      recording = build(:recording, :file_file_name => "foo.#{extension}")
      recording.should be_valid
    end
  end

  it "is not valid with a file of a different extension" do
    recording = build(:recording, :file_file_name => 'foo.swf')
    recording.should_not be_valid
    recording.errors[:base].should include("Filetype swf is not supported.  Please upload a file ending in .mp3, .wav, or .aiff")
  end

  it "should return active recordings" do
    active_recording = create(:recording, :active => true)
    inactive_recording = create(:recording, :active => false)

    Recording.active.should == [active_recording]
  end
end
