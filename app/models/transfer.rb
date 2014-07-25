class Transfer < ActiveRecord::Base
  belongs_to :script
  has_many :transfer_attempts

  validates_presence_of :phone_number
  validates_length_of :phone_number, :minimum => 10, :unless => Proc.new{|transfer| transfer.phone_number && transfer.phone_number.start_with?("+")}
  before_validation :sanitize_phone


  def self.sanitize_phone(phonenumber)
    return phonenumber if phonenumber.blank?
    append = true if phonenumber.start_with?('+')
    sanitized = phonenumber.gsub(/[^0-9]/, "")
    append ? "+#{sanitized}" : sanitized
  end

  def sanitize_phone
    self.phone_number = Transfer.sanitize_phone(phone_number) if phone_number
  end

  module Type
    WARM = "warm"
    COLD = "cold"
  end
end

# ## Schema Information
#
# Table name: `transfers`
#
# ### Columns
#
# Name                 | Type               | Attributes
# -------------------- | ------------------ | ---------------------------
# **`id`**             | `integer`          | `not null, primary key`
# **`label`**          | `string(255)`      |
# **`phone_number`**   | `string(255)`      |
# **`transfer_type`**  | `string(255)`      |
# **`script_id`**      | `integer`          |
# **`created_at`**     | `datetime`         |
# **`updated_at`**     | `datetime`         |
#
