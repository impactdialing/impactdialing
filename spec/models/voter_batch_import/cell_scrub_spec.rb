require 'spec_helper'

describe 'VoterBatchImport', data_heavy: true do
  before(:all) do
    filepath            = File.join Rails.root, 'spec', 'fixtures', 'wireless', 'nalennd_block.csv'
    wireless_block_file = File.new(filepath, 'r').read
    DoNotCall::WirelessBlockList.cache(wireless_block_file)

    expect(DoNotCall::WirelessBlockList.all.size > 0).to be_truthy

    DoNotCall::PortedList.filenames.each do |filename|
      filepath  = File.join Rails.root, 'spec', 'fixtures', 'wireless', filename
      namespace = DoNotCall::PortedList.infer_namespace(filename)
      file      = File.new(filepath, 'r').read
      DoNotCall::PortedList.cache(namespace, file)

      expect(DoNotCall::PortedList.new(namespace).all.size > 0).to be_truthy
    end
  end

  include_context 'voter csv import' do
    let(:csv_file_upload){ cp_tmp('cell_scrub_valid_voters.csv') }
    let(:csv_file) do
      CSV.new(File.open(csv_file_upload).read)
    end
    let(:file) do
      File.open(csv_file_upload)
    end
    let(:mapping) do
      csv_mapping(map_without_custom_id)
    end
  end

  let(:cell_number) do
    csv_file.rewind
    cell = csv_file.readlines[1][0]
    cell.gsub(/[^\d]/,'')
  end

  before do
    batch_import = VoterBatchImport.new(voter_list, mapping, csv_file.shift, csv_file.readlines)
    @counts      = batch_import.import_csv
  end

  describe 'returns a Hash with' do
    it 'cell => int' do
      expect(@counts[:cell]).to eq 2
    end
  end
  context 'Marking Households with cell phone numbers' do
    it 'creates a Household record when phone is a cell' do
      expect(Household.where(phone: cell_number).count).to eq 1
    end

    it 'sets Household#blocked :cell bit' do
      expect(Household.where(phone: cell_number).first.blocked?(:cell)).to be_truthy
    end
  end

  context 'Processing Households with non-cell phone numbers' do
    it 'creates a Household record when phone is not a cell' do
      # todo: make it obvious that 1st & 3rd voters have same phone number but 1st voter includes country code
      expect(Household.where('phone <> ?', cell_number).count).to eq 2
    end

    it 'does set Household#blocked :cell bit' do
      # todo: make it obvious that only the first household not matching cell_number will not have :cell bit set
      expect(Household.where('phone <> ?', cell_number).first.blocked?(:cell)).to be_falsey
    end
  end
end