require 'spec_helper'

describe 'DoNotCall::WirelessBlockParser' do
  let(:filepath) do
    # generated w/ ruby spec/fixtures/wireless/gen_list.rb block
    File.join(Rails.root, 'spec', 'fixtures', 'wireless', 'block.csv')
  end
  let(:known_cell_counts_path) do
    # 1 header
    # 69 cell phone blocks
    # 300 total data rows
    File.join(Rails.root, 'spec', 'fixtures', 'wireless', 'block-deterministic.csv')
  end
  let(:file){ File.new(filepath, 'r') }
  let(:known_cell_counts){ File.new(known_cell_counts_path, 'r') }
  let(:batch_size){ 10 }

  subject{ DoNotCall::WirelessBlockParser.new(known_cell_counts) }

  it 'yields the result of combining 3 CSV columns (NPS,NXX,X) into a single string' do
    actual_iterations   = 0
    num_lines           = 69
    expected_iterations = (num_lines / batch_size.to_f).ceil
    collected_items     = 0
    subject.in_batches(batch_size) do |batch|
      actual_iterations += 1
      collected_items += batch.size
    end
    expect(actual_iterations).to(eq(expected_iterations), "Expected to iterate on #{expected_iterations} batches but iterated #{actual_iterations}.")
  end

  it 'does include rows with Block Types not matching "C" in the results to yield' do
    parser = DoNotCall::WirelessBlockParser.new(known_cell_counts)

    not_cell_count = 300 - 69
    cell_count     = 69
    yielded_count  = 0
    parser.in_batches(batch_size) do |batch|
      yielded_count += batch.size
    end

    expect( yielded_count ).to eq cell_count
  end
end