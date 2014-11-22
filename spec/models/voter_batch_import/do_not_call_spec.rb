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

  subject{ VoterBatchImport.new(voter_list, mapping, csv_file.shift, csv_file.readlines, ',') }

  describe 'returns a Hash with' do
    it 'dnc => int' do
      expect(@counts[:dnc]).to eq 1
    end
  end
  context 'Marking Voters with phone numbers in the DNC list' do
    it 'sets :blocked bit on Voter#enabled' do
      expect(Voter.with_enabled(:list, :blocked).count).to eq(Voter.count - 1)
    end

    it 'sets :list bit on Voter#enabled' do
      expect(Voter.with_enabled(:list).count).to eq Voter.count
    end
  end

  context 'Not marking Voters with phone numbers not in the DNC list' do
    let(:not_blocked_voter) do
      Voter.where('phone <> ?', blocked_number.number).first
    end
    it 'does not set :blocked bit on Voter#enabled' do
      expect(not_blocked_voter.enabled?(:blocked)).to be_falsey
    end

    it 'sets :list bit on Voter#enabled' do
      expect(not_blocked_voter.enabled?(:list)).to be_truthy
    end
  end
end