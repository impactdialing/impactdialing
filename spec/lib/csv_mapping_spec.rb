require 'rails_helper'

describe CsvMapping do
  it "should not use the same system column as mapping for more than one csv column" do
    mapping = CsvMapping.new({
             "Phone"     => "Phone",
             "LAST"      => "LastName",
             "FIRSTName" => "LastName"
         })
    mapping.validate
    expect(mapping.errors).to include I18n.t('csv_mapping.multiple_mapping')
  end

  it "should not consider an unmapped column as a multiple mapping" do
    mapping = CsvMapping.new({
             "Phone"     => "Phone",
             "foo" => "",
             "bar" => "",
         })
    mapping.validate
    expect(mapping.errors).not_to include I18n.t('csv_mapping.multiple_mapping')
  end

  it "should mandatorily have a system mapping for Phone" do
    mapping = CsvMapping.new({
             "LAST"      => "LastName",
             "FIRSTName" => "FirstName"
         })
    mapping.validate
    expect(mapping.errors).to include I18n.t('csv_mapping.missing_phone')
  end
  it "should give the csv column mapped to the given system column" do
    mapping = CsvMapping.new({
             "Xyz"      => "Phone",
             "FIRSTName" => "FirstName"
         })
    expect(mapping.csv_index_for("Phone")).to eq("Xyz")
  end
  it "should reassign the system mapping for a given csv column" do
    mapping = CsvMapping.new({
             "Xyz"      => "Phone",
             "FIRSTName" => "FirstName"
         })
  end
end
