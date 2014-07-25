require "spec_helper"

describe Transfer, :type => :model do

  describe "phone number" do
    it "should sanitize the phone number" do
      transfer = create(:transfer, phone_number: "(203) 643-0521")
      expect(transfer.phone_number).to eq('2036430521')
    end

    it "should throw validatio error if phone number is not valid" do
      transfer = build(:transfer, phone_number: "9090909")
      expect(transfer).not_to be_valid
    end

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
