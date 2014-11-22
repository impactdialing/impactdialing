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