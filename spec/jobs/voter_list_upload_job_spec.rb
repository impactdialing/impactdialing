require 'rails_helper'
require 'voter_list_upload_job'

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
  let(:txt_file) do
    File.read(File.join(fixture_path, 'files', 'valid_voters_list.txt'))
  end
  let(:csv_file) do
    File.read(File.join(fixture_path, 'files', 'valid_voters_list.csv'))
  end
  let(:invalid_csv_file) do
    File.read(File.join(fixture_path, 'files', 'invalid_voters_list.csv'))
  end
  let(:valid_csv_to_system_map) do
    {
      "Phone" => 'phone',
      "FIRSTName" => 'first_name',
      "LAST" => 'last_name'
    }
  end
  let(:invalid_csv_to_system_map) do
    {
      'FIRSTName' => 'first_name',
      'LAST' => 'last_name'
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
  let(:web_response_strategy) do
    instance_double('VoterListWebuiStrategy', {response: nil})
  end
  let(:responder_opts) do
    {
      domain: admin.domain,
      email: admin.email,
      voter_list_name: voter_list.name
    }
  end
  before do
    allow(amazon_s3).to receive(:read).with(voter_list.s3path){ csv_file }
    allow(AmazonS3).to receive(:new){ amazon_s3 }
    allow(VoterListWebuiStrategy).to receive(:new){ web_response_strategy }
  end

  it 'downloads VoterList CSV from S3' do
    expect(amazon_s3).to receive(:read).with(voter_list.s3path)
    VoterListUploadJob.perform(voter_list.id, admin.email, admin.domain)
  end

  context 'CSV to system map is NOT valid' do
    before do
      voter_list.update_attributes! csv_to_system_map: invalid_csv_to_system_map
    end

    it 'tells the VoterListWebUiStrategy instance to respond with the error message(s)' do
      csv_mapping = CsvMapping.new(invalid_csv_to_system_map)
      csv_mapping.valid?
      expect(csv_mapping.errors).to_not be_empty
      expect(web_response_strategy).to receive(:response).with({'errors' => csv_mapping.errors, 'success' => []}, responder_opts)

      VoterListUploadJob.perform(voter_list.id, admin.email, admin.domain)
    end

    it 'returns immediately (without downloading file from S3)' do
      expect(amazon_s3).to_not receive(:read)
      VoterListUploadJob.perform(voter_list.id, admin.email, admin.domain)
    end
  end

  shared_examples 'any upload that raises ActiveRecord::StatementInvalid' do
    it 'destroys any created voters' do
      list_id = voter_list.id
      VoterListUploadJob.perform(voter_list.id, admin.email, admin.domain)
      expect(Voter.where(voter_list_id: list_id).count).to be_zero
    end

    it 'destroys the voter list' do
      list_id = voter_list.id
      VoterListUploadJob.perform(voter_list.id, admin.email, admin.domain)
      expect(VoterList.where(id: list_id).count).to be_zero
    end

    it 'returns immediately' do
      expect(VoterListUploadJob).to_not receive(:handle_success)
      VoterListUploadJob.perform(voter_list.id, admin.email, admin.domain)
    end
  end

  describe 'uploaded file triggers ActiveRecord::StatementInvalid' do
    context 'because it contains custom field values that are too long' do
      let(:lengthy_value_voter_list) do
        File.read(File.join(fixture_path, 'files', 'lengthy_custom_value_voter_list.csv'))
      end

      let(:custom_csv_to_system_map) do
        {
          "Phone" => 'phone',
          "Custom" => 'Short custom',
          "Lengthy Custom Text" => 'Long custom'
        }
      end

      before do
        voter_list.update_attributes!(csv_to_system_map: custom_csv_to_system_map)
        allow(amazon_s3).to receive(:read).with(voter_list.s3path){ lengthy_value_voter_list }
      end

      it 'tells the VoterListWebUiStrategy instance to respond with the error message(s)' do
        expect(web_response_strategy).to receive(:response).with({'errors' => [I18n.t('activerecord.errors.models.voter_list.general_error')], 'success' => []}, responder_opts)
        VoterListUploadJob.perform(voter_list.id, admin.email, admin.domain)
      end

      it_behaves_like 'any upload that raises ActiveRecord::StatementInvalid'
    end

    context 'because of other reasons' do
      let(:fake_batch_import) do
        double('FakeBatchImport')
      end

      before do
        allow(fake_batch_import).to receive(:import_csv){ raise ActiveRecord::StatementInvalid, 'Mysql2::Error: other reasons caused this' }
        allow(VoterBatchImport).to receive(:new){ fake_batch_import }
      end
      
      it 'tells the VoterListWebUiStrategy instance to respond with the error message(s)' do
        expect(web_response_strategy).to receive(:response).with({'errors' => [I18n.t('activerecord.errors.models.voter_list.general_error')], 'success' => []}, responder_opts)
        VoterListUploadJob.perform(voter_list.id, admin.email, admin.domain)
      end

      it_behaves_like 'any upload that raises ActiveRecord::StatementInvalid'
    end
  end

  shared_examples 'valid list file' do
    it 'creates 1 Voter record for each row of data' do
      VoterListUploadJob.perform(voter_list.id, admin.email, admin.domain)
      expect(Voter.count).to(eq(success_count))
    end

    it 'tells the VoterListWebUiStrategy instance to respond with the success message(s)' do
      msg      = "Upload complete. #{success_count} out of #{total_count} records imported successfully. "
      msg     += "0 out of #{success_count} records contained phone numbers in your Do Not Call list."
      msg     += " 0 records were skipped because they are assigned to cellular devices."
      response = {'errors' => [], 'success' => [msg]}

      expect(web_response_strategy).to receive(:response).with(response, responder_opts)
      VoterListUploadJob.perform(voter_list.id, admin.email, admin.domain)
    end

    it 'queues ResetVoterListCounterCache' do
      VoterListUploadJob.perform(voter_list.id, admin.email, admin.domain)
      reset_voter_list_counter_cache_job = {'class' => 'ResetVoterListCounterCache', 'args' => [voter_list.id]}
      expect(resque_jobs(:general)).to include reset_voter_list_counter_cache_job
    end
  end

  context 'CSV is valid' do
    let(:total_count){ csv_file.split("\n").size - 1 }
    let(:success_count){ total_count }

    it_behaves_like 'valid list file'
  end

  context 'file is valid TSV' do
    let(:total_count){ txt_file.split("\n").size - 1 }
    let(:success_count){ total_count }
    before do
      voter_list.update_attributes(separator: "\t")
      allow(amazon_s3).to receive(:read).with(voter_list.s3path){ txt_file }
      allow(AmazonS3).to receive(:new){ amazon_s3 }
    end

    it_behaves_like 'valid list file'
  end

  context 'CSV file is malformed in some way' do
    before do
      allow(amazon_s3).to receive(:read).with(voter_list.s3path){ invalid_csv_file }
      VoterListUploadJob.perform(voter_list.id, admin.email, admin.domain)
    end

    it 'tells the VoterList*Strategy instance to respond with the error message(s)' do
      response = {'errors' => [I18n.t('csv_validator.malformed')], 'success' => []}
    it 'tells the VoterListWebUiStrategy instance to respond with the error message(s)' do
      expect(web_response_strategy).to receive(:response).with(response, responder_opts)
      VoterListUploadJob.perform(voter_list.id, admin.email, admin.domain)
    end

    it 'returns immediately, before VoterBatchImport is instantiated' do
      expect(VoterBatchImport).to_not receive(:new)
      VoterListUploadJob.perform(voter_list.id, admin.email, admin.domain)
    end
  end

  describe 'handling Resque::TermException' do
    before do
      allow(Resque).to receive(:enqueue).and_call_original
      allow(Resque).to receive(:enqueue).once.with(ResetVoterListCounterCache, voter_list.id){ raise Resque::TermException, 'TERM' }
    end
    it 'destroys any voters already created from this list' do
      begin
        VoterListUploadJob.perform(voter_list.id, admin.email, admin.domain)
      rescue Resque::TermException
      end

      expect(Voter.where(voter_list_id: voter_list.id).count).to be_zero
    end
    it 're-queues itself with same args' do
      begin
        VoterListUploadJob.perform(voter_list.id, admin.email, admin.domain)
      rescue Resque::TermException
      end
      actual = Resque.peek('dial_queue', 0, 10)
      expected = {'class' => 'VoterListUploadJob', 'args' => [voter_list.id, admin.email, admin.domain]}
      expect(actual).to include expected
    end
  end
end