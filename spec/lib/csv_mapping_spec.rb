require "spec_helper"

describe CsvMapping do
  it "should not use the same system column as mapping for more than one csv column" do
    mapping = CsvMapping.new({
             "Phone"     => "Phone",
             "LAST"      => "LastName",
             "FIRSTName" => "LastName"
         })
    mapping.validate
    mapping.errors.should include CsvMapping::ErrorMessages::MULTIPLE_MAPPING
  end

  it "should not consider an unmapped column as a multiple mapping" do
    mapping = CsvMapping.new({
             "Phone"     => "Phone",
             "foo" => "",
             "bar" => "",
         })
    mapping.validate
    mapping.errors.should_not include CsvMapping::ErrorMessages::MULTIPLE_MAPPING
  end

  it "should mandatorily have a system mapping for Phone" do
    mapping = CsvMapping.new({
             "LAST"      => "LastName",
             "FIRSTName" => "FirstName"
         })
    mapping.validate
    mapping.errors.should include CsvMapping::ErrorMessages::NO_PHONE
  end
  it "should give the csv column mapped to the given system column" do
    mapping = CsvMapping.new({
             "Xyz"      => "Phone",
             "FIRSTName" => "FirstName"
         })
    mapping.csv_index_for("Phone").should == "Xyz"
  end
  it "should reassign the system mapping for a given csv column" do
    mapping = CsvMapping.new({
             "Xyz"      => "Phone",
             "FIRSTName" => "FirstName"
         })

  end
end