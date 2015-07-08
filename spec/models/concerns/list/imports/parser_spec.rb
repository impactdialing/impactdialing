require 'rails_helper'

describe 'List::Imports::Parser' do
  let(:voter_list){ create(:voter_list) }

  subject{ List::Imports::Parser.new(voter_list) }

  it 'exposes csv_mapping instance' do
    expect(subject.csv_mapping).to be_kind_of CsvMapping
  end
  it 'exposes batch_size int[ENV["VOTER_BATCH_SIZE"]|100]' do
    expect(subject.batch_size).to eq ENV['VOTER_BATCH_SIZE'].to_i
  end
  it 'exposes voter_list instance' do
    expect(subject.voter_list).to eq voter_list
  end
  it 'exposes results hash' do
    expect(subject.results).to be_kind_of Hash
  end
end
