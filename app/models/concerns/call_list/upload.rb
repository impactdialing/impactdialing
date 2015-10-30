class CallList::Upload
  attr_reader :parent_instance, :file, :child_instance, :namespace

private
  def save_to_s3
    s3path = "#{s3root}#{s3filename}"
    return s3path if file.nil?

    clean_file = Windozer.to_unix( file.read )
    AmazonS3.new.write(s3path, clean_file)

    s3path
  end

  def s3root
    "#{Rails.env}/uploads/#{namespace}/"
  end

public
  def initialize(parent_instance, namespace, upload_params, child_instance_params)
    new_child_method = "new_#{namespace}"
    @namespace       = namespace
    @parent_instance = parent_instance
    @file            = upload_params.try(:[], :datafile)
    @child_instance  = parent_instance.send(new_child_method, child_instance_params)
  end

  def save
    @child_instance.s3path             = save_to_s3
    @child_instance.uploaded_file_name = file.try :original_filename
  end

  def s3filename
    @s3filename ||= if child_instance.s3path.blank?
                      "#{child_instance.name}_#{Time.now.to_i}_#{rand(999)}"
                    else
                      child_instance.s3path.gsub(base_path,'')
                    end
  end
end

