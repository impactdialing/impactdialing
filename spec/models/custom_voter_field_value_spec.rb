require "spec_helper"

describe CustomVoterFieldValue do

  let(:custom_field) {create(:custom_voter_field)}
  let(:voter) { create(:voter, :phone => "34953904782") }

  it "stores a voter custom attribute value" do
    value = 'foo'
    create(:custom_voter_field_value, :voter => voter, :custom_voter_field => custom_field, :value => value)
    CustomVoterFieldValue.voter_fields(voter,custom_field).first.value.should == value
  end

  it "lists all custom field values for a voter" do
    new_field = create(:custom_voter_field)
    val1 = create(:custom_voter_field_value, :voter => voter, :custom_voter_field => custom_field, :value => 'foo' )
    val2 = create(:custom_voter_field_value, :voter => voter, :custom_voter_field => new_field, :value => 'bar')
    CustomVoterFieldValue.for(voter).should == [val1, val2]
  end

  it { should validate_presence_of :voter_id }
  it { should validate_presence_of :custom_voter_field_id }
end
