class TempVoterList < ActiveRecord::Base  
  
  validates_presence_of :name, message: "Please pick a file name."
  validate :file_format
  
  def file_format
    unless ['.csv','.txt'].include? File.extname(name||"").downcase    
      errors.add(:base, 'Wrong file format. Please upload a comma-separated value (CSV) or tab-delimited text (TXT) file. If your list is in Excel format (XLS or XLSX), use \"Save As\" to change it to one of these formats.')
    end
  end
    
  def upload_file_to_s3!(file)
    @config = YAML::load(File.open("#{Rails.root}/config/amazon_s3.yml"))
    AWS::S3::Base.establish_connection!(
        :access_key_id     => @config["access_key_id"],
        :secret_access_key => @config["secret_access_key"]
      )    
    s3path="#{Rails.env}/uploads/voter_list/#{csv_file_name}"
    AWS::S3::S3Object.store(s3path, file, @config['bucket'],:content_type =>"application/text", :access => :private)
    self.s3path = s3path
  end
  
  def csv_file_name
    "#{name}_#{Time.now.to_i}_#{rand(999)}"
  end
  
  def self.file_separator(file_name)
    (File.extname(file_name).downcase.include?('.csv')) ? ',' : "\t"
  end
  
  
    
end