class CsvValidator
  attr_reader :headers, :first_row, :csv_column_headers, :errors

  def initialize(csv_file)
    @headers = csv_file.shift || []
    @first_row = csv_file.shift || []
    @csv_column_headers = @headers.collect{|h| h.blank? ? VoterList::BLANK_HEADER : h}
    @errors = []
    validate
  end

  def validate
    if verify_headers
      verify_first_row
      duplicate_headers
    end
  end

  def verify_headers
    if (headers.empty?)
      @errors << I18n.t('activerecord.errors.models.csv.missing_header_or_rows')
      return false
    end
    true
  end

  def verify_first_row
    if (first_row.empty?)
      @errors << I18n.t('activerecord.errors.models.csv.missing_header_or_rows')
      return false
    end
    true
  end

  def duplicate_headers
    if ((headers.length - headers.uniq.length) != 0)
      duplicate_headers = headers.select{|header| headers.count(header) > 1}.uniq
      @errors << I18n.t('activerecord.errors.models.csv.duplicate_headers', :duplicate_headers => duplicate_headers.join(', '))
      return false
    end
    true
  end
end
