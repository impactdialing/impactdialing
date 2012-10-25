class CallerIdentity < ActiveRecord::Base 
 belongs_to :caller  
 
def self.create_uniq_pin
   uniq_pin=nil
   while !uniq_pin do
     pins = (0...100).map { |_| rand.to_s[2..6] }.uniq
     uniq_pin = (pins - (CallerIdentity.where(pin: pins).pluck(:pin) + Caller.where(pin: pins).pluck(:pin)).uniq).first
   end
   uniq_pin
 end
 
end
