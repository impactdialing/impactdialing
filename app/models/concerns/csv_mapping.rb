class CsvMapping
  attr_reader :errors, :mapping

  def initialize(mapping)
    @mapping = mapping
    @errors  = []
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

  def use_custom_id?
    csv_index_for('custom_id')
  end

  def valid?
    validate
    @errors.blank?
  end

  def validate
    @errors << I18n.t('csv_mapping.missing_phone') unless csv_index_for("phone")
    @errors << I18n.t('csv_mapping.multiple_mapping') if invalid_repetition_of_system_column?
  end

  def remap_system_column!(source_field, hash)
    destination_field = hash[:to]
    index = @mapping.key source_field
    if index
      @mapping[index] = destination_field
    end
  end
end
