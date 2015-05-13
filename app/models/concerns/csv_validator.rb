class CsvValidator
  attr_reader :headers, :first_row, :csv_column_headers, :errors

  def initialize(csv, separator = ',')
    @errors = []
    csv_file = CSV.new(csv, :col_sep => separator)
    begin
      @headers = csv_file.shift || []
      @first_row = csv_file.shift || []
      @csv_column_headers = @headers.collect{|h| h.blank? ? VoterList::BLANK_HEADER : h}
      validate
    rescue CSV::MalformedCSVError
      @errors << I18n.t('csv_validator.malformed')
    end
  end

  def validate
    if verify_headers
      verify_first_row
      duplicate_headers
    end
  end

  def verify_headers
    if (headers.empty?)
      @errors << I18n.t('csv_validator.missing_header_or_rows')
      return false
    end
    true
  end

  def verify_first_row
    if (first_row.empty?)
      @errors << I18n.t('csv_validator.missing_header_or_rows')
      return false
    end
    true
  end

  def duplicate_headers
    if ((headers.length - headers.uniq.length) != 0)
      duplicate_headers = headers.select{|header| headers.count(header) > 1}.uniq
      @errors << I18n.t('csv_validator.duplicate_headers', :duplicate_headers => duplicate_headers.join(', '))
      return false
    end
    true
  end
end
