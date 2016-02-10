require 'rails_helper'
require 'reports'

describe 'Reports', reports: true do
  it 'is a module' do
    expect(Reports).to be_a Module
  end
end
