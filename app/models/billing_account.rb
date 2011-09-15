class BillingAccount < ActiveRecord::Base
  belongs_to :user
#  validates_presence_of :cc

  def encyrpt_cc
    pub_key =  Crypto::Key.from_file('rsa_key.pub')
    begin
      self.cc = pub_key.encrypt(cc) if !self.cc.blank?
    rescue
      begin
        #success here means it's aready encypted
        test = self.decrypt_cc
        self.cc
      rescue
        #couldnt encrypt or decrypt, we've got issues
        raise "Could not encrypt cc #{self.cc}"
      end
    end
  end

  def decrypt_cc
     priv_key = Crypto::Key.from_file('rsa_key')
     if !self.cc.blank?
       priv_key.decrypt(self.cc)
     else
       ""
     end
  end

  def first_name
    name_arr=self.name.split(" ")
    name_arr.shift
  end

  def last_name
    name_arr=self.name.split(" ")
    name_arr.join(" ").strip
  end


end
