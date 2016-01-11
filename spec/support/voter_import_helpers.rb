RSpec.shared_context 'voter csv import' do
  def cp_tmp(filename)
    src_path = File.join fixture_path, 'files', filename
    dst_path = File.join fixture_path, 'test_tmp', filename
    FileUtils.cp src_path, dst_path
    dst_path
  end

  def csv_mapping(params)
    CsvMapping.new(params)
  end

  def upload_recording(file)
    fill_in 'Name', with: 'Ner Wecording'
    attach_file 'recording_file', Rails.root.join('spec/fixtures/files/' + file)
    click_on 'Upload'
  end

  def upload_list(file)
    click_link 'Upload'
    choose_list Rails.root.join('spec/fixtures/files/' + file)
  end

  def choose_list(file)
    attach_file 'upload_datafile', file
  end

  def process_pending_import_jobs
    job = Resque::Job.reserve(:import)
    return if job.nil?

    klass = job.payload['class'].to_s.constantize
    klass.perform(*job.payload['args'])
  end

  let(:csv_file_upload){ cp_tmp('valid_voters_list.csv') }
  let(:user) { create(:user) }
  let(:campaign) { create([:preview, :power, :predictive].sample, :account => user.account) }
  let(:voter_list) { create(:voter_list, :campaign => campaign, :account => user.account) }  
  let(:map_without_custom_id) do
    {
      "LAST" => "last_name",
      "FIRSTName" => "first_name",
      "Phone" => "phone",
      "Email" => "email"
    }
  end
  let(:map_with_custom_id) do
    map_without_custom_id.merge({
      "ID" => "custom_id"
    })
  end
end
