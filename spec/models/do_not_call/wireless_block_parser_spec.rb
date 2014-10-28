require 'spec_helper'

describe 'DoNotCall::WirelessBlockParser' do
  let(:filepath) do
    # generated w/ ruby spec/fixtures/wireless/gen_list.rb block
    File.join(Rails.root, 'spec', 'fixtures', 'wireless', 'block.csv')
  end
  let(:file){ File.new(filepath, 'r') }
  let(:batch_size){ 250_000 }

  subject{ DoNotCall::WirelessBlockParser.new(file) }

  it 'yields the result of combining 3 CSV columns (NPS,NXX,X) into a single string' do
    actual_iterations   = 0
    num_lines           = `wc -l #{filepath}`.to_i - 1 # -1 for headers
    expected_iterations = (num_lines / batch_size.to_f).ceil
    collected_items     = 0
    subject.in_batches(batch_size) do |batch|
      expect([batch_size,(num_lines % batch_size)]).to include batch.size
      actual_iterations += 1
      collected_items += batch.size
    end
    expect(actual_iterations).to(eq(expected_iterations), "Expected to iterate on #{expected_iterations} batches but iterated #{actual_iterations}.")
  end
end