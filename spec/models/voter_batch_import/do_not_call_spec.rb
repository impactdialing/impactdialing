require 'spec_helper'

describe 'VoterBatchImport' do  
  include_context 'voter csv import' do
    let(:csv_file_upload){ cp_tmp('do_not_call_valid_voters.csv') }
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

  let!(:blocked_number) do
    create(:blocked_number, number: '15554445555', account: voter_list.account)
  end

  before do
    allow(VoterList).to receive(:read_from_s3).and_return(file.read)
    @counts = subject.import_csv
  end

  subject{ VoterBatchImport.new(voter_list, mapping, csv_file.shift, csv_file.readlines) }

  describe 'returns a Hash with' do
    it 'dnc => int' do
      expect(@counts[:dnc]).to eq 1
    end
  end
  context 'Marking Voters with phone numbers in the DNC list' do
    it 'sets :dnc bit on Household#blocked' do
      expect(Household.with_blocked(:dnc).count).to eq(Voter.count - 1)
    end
  end

  context 'Not marking Voters with phone numbers not in the DNC list' do
    let(:not_blocked_household) do
      Household.where('phone <> ?', blocked_number.number).first
    end
    it 'does not set :dnc bit on Household#blocked' do
      expect(not_blocked_household.blocked?(:dnc)).to be_falsey
    end
  end
end