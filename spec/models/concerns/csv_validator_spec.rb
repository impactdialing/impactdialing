require 'rails_helper'

describe CsvValidator do
  def file_path(filename)
    File.join Rails.root, "spec/fixtures/files/#{filename}.csv"
  end

  def file(csv_file_path)
    File.read csv_file_path
  end

  describe "intialize values are properly set when file is valid" do
    let(:csv_file_path) do
      file_path 'valid_voters_list'
    end
    let(:csv_headers) do
      file(csv_file_path).gsub(/\"/, '').split.first.split(',')
    end
    let(:csv_first_row) do
      file(csv_file_path).gsub(/\"/, '').split[1].split(',').map{|c| c.blank? ? nil : c}
    end
    it "should have header content when valid file is loaded" do
      csv_validator = CsvValidator.new(file(csv_file_path))
      expect(csv_validator.headers).to eq(csv_headers)
    end
    it "should have data after the header when valid file is loaded" do
      csv_validator = CsvValidator.new(file(csv_file_path))
      expect(csv_validator.first_row).to eq(csv_first_row)
    end
    it "should have header columns when valid file is loaded" do
      csv_validator = CsvValidator.new(file(csv_file_path))
      expect(csv_validator.csv_column_headers).to eq(csv_validator.headers)
    end
    it "should have no errors when valid file is loaded" do
      csv_validator = CsvValidator.new(file(csv_file_path))
      expect(csv_validator.errors).to eq([])
    end
  end

  describe "headers are repeated" do
    let(:csv_file_path) do
      file_path 'valid_voters_duplicate_phone_headers'
    end
    it "should set headers repeated error message" do
      csv_validator = CsvValidator.new(file(csv_file_path))
      expect(csv_validator.errors).to eq ([I18n.t('csv_validator.duplicate_headers', :duplicate_headers => "PHONENUMBER")])
    end
  end

  describe "no rows are present" do
    let(:csv_file_path) do
      file_path 'voter_list_only_headers'
    end
    it "should set no rows present error message" do
      csv_validator = CsvValidator.new(file(csv_file_path))
      expect(csv_validator.errors).to eq ([I18n.t('csv_validator.missing_header_or_rows')])
    end
  end

  describe "headers are not present" do
    let(:csv_file_path) do
      file_path 'voters_with_no_header_info'
    end
    it "should set a headers not present error message" do
      csv_validator = CsvValidator.new(file(csv_file_path))
      expect(csv_validator.errors).to eq ([I18n.t('csv_validator.missing_header_or_rows')])
    end
  end

  describe "duplicate headers and no row data" do
    let(:csv_file_path) do
      file_path 'voter_list_only_headers_with_duplicates'
    end
    it "should set both duplicate headers and no row data messages" do
      csv_validator = CsvValidator.new(file(csv_file_path))
      expect(csv_validator.errors).to eq ([(I18n.t('csv_validator.missing_header_or_rows')), (I18n.t('csv_validator.duplicate_headers', :duplicate_headers => "PHONENUMBER"))])
    end
  end
end
