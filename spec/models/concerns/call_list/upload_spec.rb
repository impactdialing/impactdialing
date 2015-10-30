require 'rails_helper'

describe CallList::Upload do
  include_context 'voter csv import'
  let(:csv_file_upload_data) do
    File.new(csv_file_upload).read
  end
  let(:campaign){ create(:power) }
  let(:params) do
    {
      upload: {
        datafile: File.new(csv_file_upload)
      },
      voter_list: {
        name: "Bob's your uncle"
      }
    }
  end
  let(:amazon_s3) do
    instance_double('AmazonS3')
  end
  let(:s3filename){ 'pseudo-random-file-name' }
  let(:s3path){ "#{Rails.env}/uploads/voter_list/#{s3filename}" }
  describe '.new(campaign, params)' do
    subject{ CallList::Upload.new(campaign, :voter_list, params[:upload], params[:voter_list]) }

    it 'sets @file = params[:upload][:datafile]' do
      expect(subject.file).to eq params[:upload][:datafile]
    end
    it 'sets @parent_instance = campaign' do
      expect(subject.parent_instance).to eq campaign
    end
    it 'sets @child_instance = parent_instance.send(new_child_method)' do
      expect(subject.child_instance).to be_kind_of VoterList
    end
  end

  describe '#save' do
    subject{ CallList::Upload.new(campaign, :voter_list, params[:upload], params[:voter_list]) }

    before do
      allow(amazon_s3).to receive(:write).with(s3path, csv_file_upload_data)
      allow(subject).to receive(:s3filename){ s3filename }
      allow(Windozer).to receive(:to_unix){ csv_file_upload_data }
      allow(AmazonS3).to receive(:new){ amazon_s3 }
    end

    it 'uploads the file to S3' do
      expect(amazon_s3).to receive(:write).with(s3path, csv_file_upload_data)
      subject.save
    end
    it 'sets s3path on child_instance' do
      subject.save
      expect(subject.child_instance.s3path).to eq s3path
    end
    it 'sets uploaded_file_name on child_instance' do
      filename = File.basename csv_file_upload
      allow(subject.file).to receive(:original_filename){ filename }
      subject.save
      expect(subject.child_instance.uploaded_file_name).to eq filename
    end
  end
end

