require "spec_helper"

describe Script do
  it "restoring makes it active" do
    script = Factory(:script, :active => false)
    script.restore
    script.active?.should == true
  end

  it "sorts by the updated date" do
    Script.record_timestamps = false
    older_script = Factory(:script).tap{|c| c.update_attribute(:updated_at, 2.days.ago)}
    newer_script = Factory(:script).tap{|c| c.update_attribute(:updated_at, 1.day.ago)}
    Script.record_timestamps = true
    Script.by_updated.all.should == [newer_script, older_script]
  end

  it "gives active scripts" do
    inactive = Factory(:script, :active => false)
    active = Factory(:script, :active => true)
    Script.active.should == [active]
  end
end
