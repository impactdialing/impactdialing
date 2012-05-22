class CallerIdentity < ActiveRecord::Base 
 belongs_to :caller  
 
 def self.create_uniq_pin
   uniq_pin=0
   while uniq_pin==0 do
     pin = rand.to_s[2..6]
     check = CallerIndentity.find_by_pin(pin)
     uniq_pin=pin if check.blank?
   end
   uniq_pin
 end
 
end