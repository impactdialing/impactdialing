require 'rails_helper'

describe CsvValidator do
  describe "duplicate_headers" do
    let(:csv_file_path) do
      File.join Rails.root,'spec/fixtures/files/valid_voters_duplicate_phone_headers.csv'
    end
    let(:csv_file) do
      CSV.read(csv_file_path)
    end
    it "should generate an error when headers are duplicated" do
      duplicate_header_test = CsvValidator.new(csv_file)
      expect(duplicate_header_test.duplicate_headers).to eq I18n.t(:csv_duplicate_headers, :duplicate_headers => "PHONENUMBER")
    end
  end

  describe "first_row_present" do
    let(:csv_file_path) do
      File.join Rails.root,'spec/fixtures/files/voter_list_only_headers.csv'
    end
    let(:csv_file) do
      CSV.read(csv_file_path)
    end
    it "should generate an error when csv has no row data" do
      first_row_test = CsvValidator.new(csv_file)
      expect(first_row_test.first_row_present).to eq I18n.t(:csv_has_no_row_data)
    end
  end

  describe "headers_present" do
    let(:csv_file_path) do
      File.join Rails.root,'spec/fixtures/files/voters_with_no_header_info.csv'
    end
    let(:csv_file) do
      CSV.read(csv_file_path)
    end
    it "should generate an error when csv has no headers" do
      headers_present_test = CsvValidator.new(csv_file)
      expect(headers_present_test.headers_present).to eq I18n.t(:csv_has_no_header_data)
    end
  end

  describe "validate duplicate_headers" do
    let(:csv_file_path) do
      File.join Rails.root,'spec/fixtures/files/valid_voters_duplicate_phone_headers.csv'
    end
    let(:csv_file) do
      CSV.read(csv_file_path)
    end
    it "should generate an error when headers are duplicated" do
      validate_test = CsvValidator.new(csv_file)
      expect(validate_test.validate).to eq I18n.t(:csv_duplicate_headers, :duplicate_headers => "PHONENUMBER")
    end
  end

  describe "validate first_row_present" do
    let(:csv_file_path) do
      File.join Rails.root,'spec/fixtures/files/voter_list_only_headers_with_duplicates.csv'
    end
    let(:csv_file) do
      CSV.read(csv_file_path)
    end
    it "should generate an error stating csv has duplicate headers and no row data" do
      validate_test = CsvValidator.new(csv_file)
      expect(validate_test.validate).to eq (I18n.t(:csv_has_no_row_data) + I18n.t(:csv_duplicate_headers, :duplicate_headers => "PHONENUMBER"))
    end
  end

end
  # it "should not use the same system column as mapping for more than one csv column" do
  #   mapping = CsvMapping.new({
  #            "Phone"     => "Phone",
  #            "LAST"      => "LastName",
  #            "FIRSTName" => "LastName"
  #        })
  #   mapping.validate
  #   expect(mapping.errors).to include CsvMapping::ErrorMessages::MULTIPLE_MAPPING
  # end
  #
  # it "should not consider an unmapped column as a multiple mapping" do
  #   mapping = CsvMapping.new({
  #            "Phone"     => "Phone",
  #            "foo" => "",
  #            "bar" => "",
  #        })
  #   mapping.validate
  #   expect(mapping.errors).not_to include CsvMapping::ErrorMessages::MULTIPLE_MAPPING
  # end
  #
  # it "should mandatorily have a system mapping for Phone" do
  #   mapping = CsvMapping.new({
  #            "LAST"      => "LastName",
  #            "FIRSTName" => "FirstName"
  #        })
  #   mapping.validate
  #   expect(mapping.errors).to include CsvMapping::ErrorMessages::NO_PHONE
  # end
  # it "should give the csv column mapped to the given system column" do
  #   mapping = CsvMapping.new({
  #            "Xyz"      => "Phone",
  #            "FIRSTName" => "FirstName"
  #        })
  #   expect(mapping.csv_index_for("Phone")).to eq("Xyz")
  # end
  # it "should reassign the system mapping for a given csv column" do
  #   mapping = CsvMapping.new({
  #            "Xyz"      => "Phone",
  #            "FIRSTName" => "FirstName"
  #        })
  # end
