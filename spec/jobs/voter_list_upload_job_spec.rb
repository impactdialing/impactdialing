require 'spec_helper'

describe 'VoterListUploadJob' do
  let(:amazon_s3) do
    double('AmazonS3', {
      read: nil
    })
  end
  let(:account){ create(:account) }
  let(:admin){ create(:user, account: account) }
  let(:campaign){ create(:power, account: account) }
  let(:s3path){ '/bucket/folder/filename.csv' }
  let(:csv_file) do
    File.read(File.join(fixture_path, 'files', 'valid_voters_list.csv'))
  end
  let(:invalid_csv_file) do
    File.read(File.join(fixture_path, 'files', 'invalid_voters_list.csv'))
  end
  let(:valid_csv_to_system_map) do
    {
      "Phone" => 'phone',
      "FIRSTName" => 'fname',
      "LAST" => 'lname'
    }
  end
  let(:invalid_csv_to_system_map) do
    {
      'FIRSTName' => 'fname',
      'LAST' => 'lname'
    }
  end
  let(:voter_list) do
    create(:voter_list, {
      name: 'filename',
      s3path: s3path,
      account: account,
      campaign: campaign,
      csv_to_system_map: valid_csv_to_system_map
    })
  end
  let(:domain){ admin.domain }
  let(:email){ admin.email }
  let(:callback_url){ '' }
  let(:strategy){ 'webui' }
  let(:web_response_strategy) do
    instance_double('VoterListWebuiStrategy', {response: nil})
  end
  let(:api_response_strategy) do
    instance_double('VoterListApiStrategy', {response: nil})
  end
  let(:responder_opts) do
    {
      domain: admin.domain,
      email: admin.email,
      voter_list_name: voter_list.name
    }
  end
  before do
    Resque.redis.del "queue:upload_download"
    allow(amazon_s3).to receive(:read).with(voter_list.s3path){ csv_file }
    allow(AmazonS3).to receive(:new){ amazon_s3 }
    allow(VoterListWebuiStrategy).to receive(:new){ web_response_strategy }
    allow(VoterListApiStrategy).to receive(:new){ api_response_strategy }
  end

  it 'downloads VoterList CSV from S3' do
    expect(amazon_s3).to receive(:read).with(voter_list.s3path)
    VoterListUploadJob.perform(voter_list.id, admin.email, admin.domain, callback_url, strategy)
  end

  context 'CSV to system map is NOT valid' do
    before do
      voter_list.update_attributes! csv_to_system_map: invalid_csv_to_system_map
    end

    it 'tells the VoterList*Strategy instance to respond with the error message(s)' do
      csv_mapping = CsvMapping.new(invalid_csv_to_system_map)
      csv_mapping.valid?
      expect(csv_mapping.errors).to_not be_empty
      expect(web_response_strategy).to receive(:response).with({'errors' => csv_mapping.errors, 'success' => []}, responder_opts)

      VoterListUploadJob.perform(voter_list.id, admin.email, admin.domain, callback_url, strategy)
    end

    it 'returns immediately (without downloading file from S3)' do
      expect(amazon_s3).to_not receive(:read)
      VoterListUploadJob.perform(voter_list.id, admin.email, admin.domain, callback_url, strategy)
    end
  end

  context 'CSV is valid' do
    let(:total_count){ csv_file.split("\n").size - 1 }
    let(:success_count){ total_count }

    it 'creates 1 Voter record for each row of data' do
      VoterListUploadJob.perform(voter_list.id, admin.email, admin.domain, callback_url, strategy)
      expect(Voter.count).to(eq(success_count))
    end

    it 'tells the VoterList*Strategy instance to respond with the success message(s)' do
      msg      = "Upload complete. #{success_count} out of #{total_count} records imported successfully. "
      msg     += "0 out of #{success_count} records contained phone numbers in your Do Not Call list."
      msg     += " 0 records were skipped because they are assigned to cellular devices."
      response = {'errors' => [], 'success' => [msg]}

      expect(web_response_strategy).to receive(:response).with(response, responder_opts)
      VoterListUploadJob.perform(voter_list.id, admin.email, admin.domain, callback_url, strategy)
    end

    it 'queues ResetVoterListCounterCache' do
      VoterListUploadJob.perform(voter_list.id, admin.email, admin.domain, callback_url, strategy)
      actual = Resque.peek('upload_download', 0, 10)
      expected = {'class' => 'ResetVoterListCounterCache', 'args' => [voter_list.id]}
      expect(actual).to include expected
    end
  end

  context 'CSV file is malformed in some way' do
    before do
      allow(amazon_s3).to receive(:read).with(voter_list.s3path){ invalid_csv_file }
      VoterListUploadJob.perform(voter_list.id, admin.email, admin.domain, callback_url, strategy)
    end

    it 'tells the VoterList*Strategy instance to respond with the error message(s)' do
      response = {'errors' => [I18n.t(:csv_is_invalid)], 'success' => []}
      expect(web_response_strategy).to receive(:response).with(response, responder_opts)
      VoterListUploadJob.perform(voter_list.id, admin.email, admin.domain, callback_url, strategy)
    end

    it 'returns immediately, before VoterBatchImport is instantiated' do
      expect(VoterBatchImport).to_not receive(:new)
      VoterListUploadJob.perform(voter_list.id, admin.email, admin.domain, callback_url, strategy)
    end
  end

  describe 'handling Resque::TermException' do
    before do
      allow(Resque).to receive(:enqueue).and_call_original
      allow(Resque).to receive(:enqueue).once.with(ResetVoterListCounterCache, voter_list.id){ raise Resque::TermException, 'TERM' }
    end
    it 'destroys any voters already created from this list' do
      begin
        VoterListUploadJob.perform(voter_list.id, admin.email, admin.domain, callback_url, strategy)
      rescue Resque::TermException
      end

      expect(Voter.where(voter_list_id: voter_list.id).count).to be_zero
    end
    it 're-queues itself with same args' do
      begin
        VoterListUploadJob.perform(voter_list.id, admin.email, admin.domain, callback_url, strategy)
      rescue Resque::TermException
      end
      actual = Resque.peek('upload_download', 0, 10)
      expected = {'class' => 'VoterListUploadJob', 'args' => [voter_list.id, admin.email, admin.domain, callback_url, strategy]}
      expect(actual).to include expected
    end
  end
end