require "spec_helper"

describe TempVoterList do
  
  describe "valid file" do
    
     it "should consider csv file extension as valid" do
       TempVoterList.new(name: "abc.csv").save.should be_true
     end

     it "should consider CSV file extension as valid" do
       TempVoterList.new(name: "abc.CSV").save.should be_true
     end

     it "should consider txt file extension as valid" do
       TempVoterList.new(name: "abc.txt").save.should be_true
     end

     it "should consider null fileas invalid" do
       TempVoterList.new().save.should be_false       
     end

     it "should consider non csv txt file as invalid" do
       TempVoterList.new(name: "abc.psd").save.should be_false              
     end
  end
  
end

