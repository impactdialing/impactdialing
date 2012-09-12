require "spec_helper"

describe TimeZoneHelper do
  
  describe "set_date_range" do
     it "should raise exception if date not in correct format" do
        campaign = Factory(:campaign)        
        expect { helper.set_date_range(campaign, "", "") }.to raise_error(InvalidDateException)
     end     
  end
end