class CsvValidator
  attr_reader :headers, :first_row, :csv_column_headers

  def initialize(csv_file)
    @headers = csv_file.shift
    @first_row = csv_file.shift
    @csv_column_headers = @headers.collect{|h| h.blank? ? VoterList::BLANK_HEADER : h}
    @errors = []
  end

  def validate
    if headers_present
    else
      first_row_present
      duplicate_headers
    end
    return @errors
  end

  def headers_present
    unless headers.present?
      @errors << I18n.t(:csv_has_no_header_data)
      # return I18n.t(:csv_has_no_header_data)
    end
  end

  def first_row_present
    unless first_row.present?
      @errors << I18n.t(:csv_has_no_row_data)
      # return I18n.t(:csv_has_no_row_data)
    end
  end

  def duplicate_headers
    if ((headers.length - headers.uniq.length) != 0)
      duplicate_headers = headers.select{|header| headers.count(header) > 1}.uniq
      @errors << I18n.t(:csv_duplicate_headers, :duplicate_headers => duplicate_headers.join(', '))
      # return I18n.t(:csv_duplicate_headers, :duplicate_headers => duplicate_headers.join(', '))
    end
  end

  # def header
  #   @CsvValidator.new(@header)
  # end
  #
  # def first_row
  #   @CsvValidator.new(@first_row)
  # end


  # ---- CSVImportCheck.error_check(headers, csv_file) ----
  # one method would call the others.
  # each error check would be a method.
  # or

  # if CSVImportCheck.headers_present(headers)
  #   @csv_error = I18n.t(:csv_has_no_header_data)
  # elsif CSVImportCheck.no_row_data(headers,csv_file)
  #   @csv_error = I18n.t(:csv_has_no_row_data)
  # elsif CSVImportCheck.duplicate_headers(headers)
  #   @csv_error = I18n.t(:csv_duplicate_headers, :duplicate_headers => duplicate_headers.join(', '))
  # end

  # unless headers.present?
  #   @csv_error = I18n.t(:csv_has_no_header_data)
  # else
  #   @csv_column_headers = headers.collect{|h| h.blank? ? VoterList::BLANK_HEADER : h}
  #   @first_data_row = csv_file.shift
  #   unless @first_data_row.present?
  #     @csv_error = I18n.t(:csv_has_no_row_data)
  #   else
  #     if ((headers.length - headers.uniq.length) != 0)
  #       duplicate_headers = headers.select{|header| headers.count(header) > 1}.uniq
  #       @csv_error = I18n.t(:csv_duplicate_headers, :duplicate_headers => duplicate_headers.join(', '))
  #     end
  #   end
  # end

end
