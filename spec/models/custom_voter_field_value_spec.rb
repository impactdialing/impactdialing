require "spec_helper"

describe CustomVoterFieldValue, :type => :model do

  let(:custom_field) {create(:custom_voter_field)}
  let(:voter) { create(:voter, :phone => "34953904782") }

  it "stores a voter custom attribute value" do
    value = 'foo'
    create(:custom_voter_field_value, :voter => voter, :custom_voter_field => custom_field, :value => value)
    expect(CustomVoterFieldValue.voter_fields(voter,custom_field).first.value).to eq(value)
  end

  it "lists all custom field values for a voter" do
    new_field = create(:custom_voter_field)
    val1 = create(:custom_voter_field_value, :voter => voter, :custom_voter_field => custom_field, :value => 'foo' )
    val2 = create(:custom_voter_field_value, :voter => voter, :custom_voter_field => new_field, :value => 'bar')
    expect(CustomVoterFieldValue.for(voter)).to eq([val1, val2])
  end

  it { is_expected.to validate_presence_of :voter_id }
  it { is_expected.to validate_presence_of :custom_voter_field_id }
end

# ## Schema Information
#
# Table name: `custom_voter_field_values`
#
# ### Columns
#
# Name                         | Type               | Attributes
# ---------------------------- | ------------------ | ---------------------------
# **`id`**                     | `integer`          | `not null, primary key`
# **`voter_id`**               | `integer`          |
# **`custom_voter_field_id`**  | `integer`          |
# **`value`**                  | `string(255)`      |
#
# ### Indexes
#
# * `index_custom_voter_field_values_on_voter_id`:
#     * **`voter_id`**
#
