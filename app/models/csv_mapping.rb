class CsvMapping
  attr_reader :errors

  module ErrorMessages
    MULTIPLE_MAPPING = "Could not import. Two columns in the uploaded file were mapped to the same destination."
    NO_PHONE = "Could not import. You did not map any column in the uploaded file to Phone"
  end

  def initialize(mapping)
    @mapping = mapping
    @errors = []
  end

  def csv_index_for(system_column_title)
    @mapping.key(system_column_title)
  end

  def system_column_for(csv_column_title)
    @mapping[csv_column_title]
  end

  def invalid_repetition_of_system_column?
    mapped = @mapping.reject { |column, mapped_to| mapped_to.blank? }
    not (mapped.values.uniq.count == mapped.values.count)
  end

  def valid?
    validate
    @errors.blank?
  end

  def validate
    @errors = []
    @errors << ErrorMessages::NO_PHONE unless csv_index_for("phone")
    @errors << ErrorMessages::MULTIPLE_MAPPING if invalid_repetition_of_system_column?
  end

  def remap_system_column!(source_field, hash)
    destination_field = hash[:to]
    index = @mapping.key source_field
    if index
      @mapping[index] = destination_field
    end
  end
end
