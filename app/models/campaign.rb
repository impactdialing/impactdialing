class Campaign < ActiveRecord::Base
  require "fastercsv"
  validates_presence_of :name, :on => :create, :message => "can't be blank"
  has_and_belongs_to_many :voter_lists
  has_and_belongs_to_many :callers
  belongs_to :script
  cattr_reader :per_page
  @@per_page = 25
  
  def before_create
    uniq_pin=0
    while uniq_pin==0 do
      pin = rand.to_s[2..6]
      check = Campaign.find_by_group_id(pin)
      uniq_pin=pin if check.blank?
    end
    self.group_id = uniq_pin
  end

  def voters(status=nil)
    voters=[]
    self.voter_lists.each do |list|
      list.voters.each do |voter|
        if status==nil
          voters << voter if voter.active==1 && voters.index(voter)==nil
        else
          voters << voter if voter.active==1 && voter.status==status && voters.index(voter)==nil
        end
      end
    end
    voters
  end
  
  def voter_upload(upload,uid,seperator,voter_list_id)
    name = upload['datafile'].original_filename
    directory = "/tmp"
    path = File.join(directory, name)
    File.open(path, "wb") { |f| f.write(upload['datafile'].read) }
    
    all_headers=["Phone","VAN ID","LastName","FirstName","MiddleName","Suffix","Email"]
    headers_present={}
    num = 0
    pos=0
    result={:uploads=>[]}
    successCount=0
    failedCount=0

    FasterCSV.foreach(path, {:col_sep => seperator}) do |col|
      if num == 0
        # finding the col values
        col.each do |c|
          all_headers.each do |h|
            if h.downcase==c.downcase.strip
              headers_present[c.strip]=pos
            end
          end
          pos +=1
          
          # unless the column value is "R.No"(which is a roll no of student) find the subject using the abbreviation of that subject
          # unless c == "R.No"
          #   subj = Subject.first(:conditions => ["abbreviation = '#{c}'"])
          #   if subj.present?
          #     m.push(subj.id)
          #   end
          # end
        end
      else
        # process column
        if !headers_present.has_key?("Phone")
          return {:error=>"Could not process upload file.  Missing column header: Phone"}
        end
        
        #validation
        if col[headers_present["Phone"]]==nil || !phone_number_valid(col[headers_present["Phone"]])
          result[:uploads] << "Row " + (num+1).to_s + ": Invalid phone number"
          failedCount+=1
        elsif Voter.find_by_Phone_and_voter_list_id_and_active(phone_format(col[headers_present["Phone"]]),voter_list_id,true)
          result[:uploads] << "Row "  + (num+1).to_s + ": " + format_number_to_phone(col[headers_present["Phone"]]) + " already in this list"
          failedCount+=1
        else
          #valid row
          v = Voter.new
          v.campaign_id=self.id
          v.user_id=uid
          headers_present.keys.each do |h|
            #RAILS_DEFAULT_LOGGER.debug("#{h}: #{headers_present[h]}, #{col[headers_present[h]]}")
            thisHeader = h
            thisHeader="CustomID" if thisHeader=="VAN ID"
           # RAILS_DEFAULT_LOGGER.debug("thisHeader: #{thisHeader}, #{h}")
           if thisHeader=="Phone"
             val = phone_format(col[headers_present[h]])
           else
             val = col[headers_present[h]]
           end
           val="" if val==nil
            v.attributes={thisHeader=>val}
          end
          v.voter_list_id=voter_list_id
          v.save
          successCount+=1
        end
      end
      num += 1
    end
#    RAILS_DEFAULT_LOGGER.debug("present: #{headers_present.to_yaml}")
  result[:successCount]=successCount
  result[:failedCount]=failedCount
    return result
  end


  def phone_format(str)
    return "" if str.blank?
    str.gsub(/[^0-9]/, "")
  end

  def phone_number_valid(str)
    if (str.blank?)
      return false
    end
    str.scan(/[0-9]/).size > 9
  end

  
 def format_number_to_phone(number, options = {})
    number       = number.to_s.strip unless number.nil?
   options      = options.symbolize_keys
   area_code    = options[:area_code] || nil
   delimiter    = options[:delimiter] || "-"
   extension    = options[:extension].to_s.strip || nil
   country_code = options[:country_code] || nil

   begin
     str = ""
     str << "+#{country_code}#{delimiter}" unless country_code.blank?
     str << if area_code
     number.gsub!(/([0-9]{1,3})([0-9]{3})([0-9]{4}$)/,"(\\1) \\2#{delimiter}\\3")
     else
       number.gsub!(/([0-9]{0,3})([0-9]{3})([0-9]{4})$/,"\\1#{delimiter}\\2#{delimiter}\\3")
       number.starts_with?('-') ? number.slice!(1..-1) : number
     end
     str << " x #{extension}" unless extension.blank?
     str
   rescue
     number
   end


 end
 
end
