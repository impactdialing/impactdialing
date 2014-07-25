class CallerIdentity < ActiveRecord::Base 
 belongs_to :caller  
 
def self.create_uniq_pin
   uniq_pin=nil
   while !uniq_pin do
     pins = (0...100).map { |_| rand.to_s[2..8] }.uniq
     uniq_pin = (pins - (CallerIdentity.where(pin: pins).pluck(:pin) + Caller.where(pin: pins).pluck(:pin)).uniq).first
   end
   uniq_pin
 end
 
end

# ## Schema Information
#
# Table name: `caller_identities`
#
# ### Columns
#
# Name                     | Type               | Attributes
# ------------------------ | ------------------ | ---------------------------
# **`id`**                 | `integer`          | `not null, primary key`
# **`session_key`**        | `string(255)`      |
# **`caller_session_id`**  | `integer`          |
# **`caller_id`**          | `integer`          |
# **`pin`**                | `string(255)`      |
# **`created_at`**         | `datetime`         |
# **`updated_at`**         | `datetime`         |
#
# ### Indexes
#
# * `index_caller_identities_pin`:
#     * **`pin`**
#
