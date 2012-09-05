require 'spec_helper'

describe ScriptText do
  context 'validations' do
    it {should validate_presence_of :content}
    it {should validate_presence_of :script}
    it {should validate_presence_of :script_order}
    it {should validate_numericality_of :script_order}
  end
end
